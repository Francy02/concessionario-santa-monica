-- Migrazione v2: provvigioni automatiche e pagamento
-- Eseguire nel SQL Editor di Supabase dopo schema.sql e first-owner.sql
begin;

-- 1. Nuove colonne
alter table public.members add column if not exists commission_pct numeric(5,2) not null default 0 check(commission_pct >= 0 and commission_pct <= 100);
alter table public.sales add column if not exists commission_paid boolean not null default false;

-- 2. Aggiorna save_member con percentuale provvigione
drop function if exists public.save_member(text,text,text,boolean);
create function public.save_member(p_discord_id text,p_name text,p_role text,p_active boolean,p_commission_pct numeric default 0) returns void language plpgsql security definer set search_path='' as $$
declare who text:=public.my_discord();
begin
  perform pg_advisory_xact_lock(741856);
  if public.my_role() is distinct from 'owner' then raise exception 'Solo il titolare può gestire gli accessi';end if;
  if p_discord_id=who and (p_role<>'owner' or not p_active) then raise exception 'Non puoi revocare il tuo accesso da titolare';end if;
  insert into public.members(discord_id,name,role,active,commission_pct) values(p_discord_id,trim(p_name),p_role,p_active,p_commission_pct)
  on conflict(discord_id) do update set name=excluded.name,role=excluded.role,active=excluded.active,commission_pct=excluded.commission_pct;
  if not p_active then update public.shifts set ended_at=now() where discord_id=p_discord_id and ended_at is null;end if;
  insert into public.audit(actor,action) values(who,'Accesso aggiornato: '||p_discord_id||' / '||p_role||' / attivo='||p_active||' / provvigione='||p_commission_pct||'%');
end $$;

-- 3. Aggiorna record_sale: la provvigione viene calcolata dalla percentuale del venditore
drop function if exists public.record_sale(text,text,text,numeric,numeric,numeric);
create function public.record_sale(p_customer text,p_vehicle text,p_plate text,p_price numeric,p_cost numeric) returns uuid language plpgsql security definer set search_path='' as $$
declare who text:=public.my_discord(); sale uuid; pct numeric; comm numeric;
begin
  select commission_pct into pct from public.members where discord_id=who and active for update;
  if not found then raise exception 'Accesso non autorizzato'; end if;
  comm := round(p_price * pct / 100, 2);
  insert into public.sales(discord_id,customer,vehicle,plate,price,cost,commission) values(who,trim(p_customer),trim(p_vehicle),trim(p_plate),p_price,p_cost,comm) returning id into sale;
  insert into public.entries(discord_id,description,amount,category,sale_id) values(who,'Vendita: '||trim(p_vehicle),p_price,'Vendita',sale);
  insert into public.audit(actor,action) values(who,'Vendita registrata: '||sale);
  return sale;
end $$;

-- 4. Nuova funzione: pagamento provvigioni
create function public.pay_commission(p_discord_id text) returns void language plpgsql security definer set search_path='' as $$
declare who text:=public.my_discord(); total numeric; member_name text;
begin
  if public.my_role() is distinct from 'owner' then raise exception 'Solo il titolare può pagare le provvigioni'; end if;
  select name into member_name from public.members where discord_id=p_discord_id;
  if not found then raise exception 'Dipendente non trovato'; end if;
  select coalesce(sum(commission), 0) into total from public.sales where discord_id=p_discord_id and not voided and not commission_paid;
  if total <= 0 then raise exception 'Nessuna provvigione da pagare'; end if;
  update public.sales set commission_paid = true where discord_id = p_discord_id and not voided and not commission_paid;
  insert into public.entries(discord_id, description, amount, category) values(who, 'Pagamento provvigioni: ' || member_name, -total, 'Provvigioni');
  insert into public.audit(actor, action) values(who, 'Provvigioni pagate a ' || member_name || ': $' || total);
end $$;

-- 5. Permessi sulle nuove funzioni
revoke execute on function public.save_member(text,text,text,boolean,numeric) from public, anon;
revoke execute on function public.record_sale(text,text,text,numeric,numeric) from public, anon;
revoke execute on function public.pay_commission(text) from public, anon;
grant execute on function public.save_member(text,text,text,boolean,numeric) to authenticated;
grant execute on function public.record_sale(text,text,text,numeric,numeric) to authenticated;
grant execute on function public.pay_commission(text) to authenticated;

commit;
