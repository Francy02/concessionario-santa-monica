-- Migrazione v3: eliminazione dipendente
begin;

create function public.delete_member(p_discord_id text) returns void language plpgsql security definer set search_path='' as $$
declare who text:=public.my_discord(); member_name text;
begin
  if public.my_role() is distinct from 'owner' then raise exception 'Solo il titolare può gestire gli accessi'; end if;
  if p_discord_id = who then raise exception 'Non puoi eliminare il tuo accesso da titolare'; end if;
  
  select name into member_name from public.members where discord_id=p_discord_id;
  if not found then raise exception 'Dipendente non trovato'; end if;

  begin
    delete from public.members where discord_id = p_discord_id;
    insert into public.audit(actor, action) values(who, 'Dipendente eliminato: ' || member_name || ' (' || p_discord_id || ')');
  exception
    when foreign_key_violation then
      raise exception 'Impossibile eliminare questo dipendente perché ha vendite o turni registrati. Modifica l''accesso impostandolo su "Disabilitato" invece di eliminarlo.';
  end;
end $$;

revoke execute on function public.delete_member(text) from public, anon;
grant execute on function public.delete_member(text) to authenticated;

commit;
