-- Eseguire una volta nel SQL Editor di un nuovo progetto Supabase.
begin;
create table public.members(discord_id text primary key check(discord_id ~ '^[0-9]{17,20}$'),name text not null check(length(name) between 1 and 100),role text not null check(role in ('owner','manager','employee')),active boolean not null default true);
create table public.shifts(id uuid primary key default gen_random_uuid(),discord_id text not null references public.members,started_at timestamptz not null default now(),ended_at timestamptz check(ended_at>=started_at));
create unique index one_open_shift on public.shifts(discord_id) where ended_at is null;
create table public.sales(id uuid primary key default gen_random_uuid(),discord_id text not null references public.members,customer text not null check(length(customer) between 1 and 150),vehicle text not null check(length(vehicle) between 1 and 150),plate text not null default '' check(length(plate)<=30),price numeric(14,2) not null check(price>0),cost numeric(14,2) not null check(cost>=0),commission numeric(14,2) not null default 0 check(commission>=0 and commission<=price),created_at timestamptz not null default now(),voided boolean not null default false);
create table public.entries(id uuid primary key default gen_random_uuid(),discord_id text not null references public.members,description text not null check(length(description) between 1 and 300),amount numeric(14,2) not null check(amount<>0),category text not null,sale_id uuid references public.sales,created_at timestamptz not null default now());
create table public.audit(id uuid primary key default gen_random_uuid(),actor text not null,action text not null,created_at timestamptz not null default now());
create index shifts_date on public.shifts(started_at);
create index sales_date on public.sales(created_at);
create index entries_date on public.entries(created_at);
alter table public.sales add constraint finite_money check(price < 1000000000000 and cost < 1000000000000 and commission < 1000000000000);
alter table public.entries add constraint finite_amount check(abs(amount) < 1000000000000);

-- L'identità proviene da auth.identities, non da metadati modificabili dal browser.
create function public.my_discord() returns text language sql stable security definer set search_path='' as $$ select provider_id from auth.identities where user_id=auth.uid() and provider='discord' limit 1 $$;
create function public.my_role() returns text language sql stable security definer set search_path='' as $$ select role from public.members where discord_id=public.my_discord() and active $$;
alter table public.members enable row level security;
alter table public.shifts enable row level security;
alter table public.sales enable row level security;
alter table public.entries enable row level security;
alter table public.audit enable row level security;
create policy members_read on public.members for select to authenticated using(public.my_role() is not null);
create policy shifts_read on public.shifts for select to authenticated using(public.my_role() in ('owner','manager') or (public.my_role()='employee' and discord_id=public.my_discord()));
create policy sales_read on public.sales for select to authenticated using(public.my_role() in ('owner','manager') or (public.my_role()='employee' and discord_id=public.my_discord()));
create policy entries_read on public.entries for select to authenticated using(public.my_role() in ('owner','manager'));
create policy audit_read on public.audit for select to authenticated using(public.my_role() in ('owner','manager'));
revoke all on public.members,public.shifts,public.sales,public.entries,public.audit from anon,authenticated;
grant select on public.members,public.shifts,public.sales,public.entries,public.audit to authenticated;

create function public.punch() returns void language plpgsql security definer set search_path='' as $$
declare who text:=public.my_discord(); open_id uuid;
begin
 perform 1 from public.members where discord_id=who and active for update;
 if not found then raise exception 'Accesso non autorizzato'; end if;
 select id into open_id from public.shifts where discord_id=who and ended_at is null;
 if open_id is null then
 insert into public.shifts(discord_id) values(who);
 insert into public.audit(actor,action) values(who,'Entrata in servizio');
 else
 update public.shifts set ended_at=now() where id=open_id;
 insert into public.audit(actor,action) values(who,'Uscita dal servizio');
 end if;
end $$;

create function public.record_sale(p_customer text,p_vehicle text,p_plate text,p_price numeric,p_cost numeric,p_commission numeric) returns uuid language plpgsql security definer set search_path='' as $$
declare who text:=public.my_discord(); sale uuid;
begin
 perform 1 from public.members where discord_id=who and active for update;
 if not found then raise exception 'Accesso non autorizzato'; end if;
 insert into public.sales(discord_id,customer,vehicle,plate,price,cost,commission) values(who,trim(p_customer),trim(p_vehicle),trim(p_plate),p_price,p_cost,p_commission) returning id into sale;
 -- L'incasso genera una sola entrata. Il costo è analitico: i pagamenti fornitori vanno registrati in cassa.
 insert into public.entries(discord_id,description,amount,category,sale_id) values(who,'Vendita: '||trim(p_vehicle),p_price,'Vendita',sale);
 insert into public.audit(actor,action) values(who,'Vendita registrata: '||sale);
 return sale;
end $$;

create function public.record_entry(p_description text,p_amount numeric,p_category text) returns void language plpgsql security definer set search_path='' as $$
declare who text:=public.my_discord();
begin
 perform 1 from public.members where discord_id=who and active and role in ('owner','manager') for update;
 if not found then raise exception 'Permessi insufficienti';end if;
 if p_category not in ('Acquisto veicolo','Stipendi','Provvigioni','Spese','Versamento','Altro') then raise exception 'Categoria non valida';end if;
 insert into public.entries(discord_id,description,amount,category) values(who,trim(p_description),p_amount,p_category);
 insert into public.audit(actor,action) values(who,'Movimento di cassa: '||p_amount||' — '||trim(p_description));
end $$;

create function public.void_sale(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare who text:=public.my_discord(); sale public.sales;
begin
 perform 1 from public.members where discord_id=who and active and role in ('owner','manager') for update;
 if not found then raise exception 'Permessi insufficienti';end if;
 select * into sale from public.sales where id=p_id for update;
 if not found or sale.voided then raise exception 'Vendita inesistente o già annullata';end if;
 update public.sales set voided=true where id=p_id;
 insert into public.entries(discord_id,description,amount,category,sale_id) values(who,'Storno: '||sale.vehicle,-sale.price,'Storno',p_id);
 insert into public.audit(actor,action) values(who,'Vendita annullata: '||p_id);
end $$;

create function public.save_member(p_discord_id text,p_name text,p_role text,p_active boolean) returns void language plpgsql security definer set search_path='' as $$
declare who text:=public.my_discord();
begin
 -- Serializza i cambi ruoli, anche se effettuati da titolari diversi.
 perform pg_advisory_xact_lock(741856);
 if public.my_role() is distinct from 'owner' then raise exception 'Solo il titolare può gestire gli accessi';end if;
 if p_discord_id=who and (p_role<>'owner' or not p_active) then raise exception 'Non puoi revocare il tuo accesso da titolare';end if;
 insert into public.members(discord_id,name,role,active) values(p_discord_id,trim(p_name),p_role,p_active)
 on conflict(discord_id) do update set name=excluded.name,role=excluded.role,active=excluded.active;
 if not p_active then update public.shifts set ended_at=now() where discord_id=p_discord_id and ended_at is null;end if;
 insert into public.audit(actor,action) values(who,'Accesso aggiornato: '||p_discord_id||' / '||p_role||' / attivo='||p_active);
end $$;

create function public.close_shift(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if public.my_role() not in ('owner','manager') or public.my_role() is null then raise exception 'Permessi insufficienti';end if;
 update public.shifts set ended_at=now() where id=p_id and ended_at is null;
 if not found then raise exception 'Turno già chiuso o inesistente';end if;
 insert into public.audit(actor,action) values(public.my_discord(),'Chiusura turno dimenticato: '||p_id);
end $$;

revoke execute on function public.my_discord(),public.my_role(),public.punch(),public.record_sale(text,text,text,numeric,numeric,numeric),public.record_entry(text,numeric,text),public.void_sale(uuid),public.save_member(text,text,text,boolean),public.close_shift(uuid) from public,anon;
grant execute on function public.my_discord(),public.my_role(),public.punch(),public.record_sale(text,text,text,numeric,numeric,numeric),public.record_entry(text,numeric,text),public.void_sale(uuid),public.save_member(text,text,text,boolean),public.close_shift(uuid) to authenticated;
commit;

-- DOPO: inserire il proprio ID Discord nel SQL Editor (non un nome utente):
-- insert into public.members(discord_id,name,role) values('IL_TUO_ID_DISCORD','Il tuo nome RP','owner');
