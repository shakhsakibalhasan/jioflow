begin;
-- Import only: restore the phone-matched customer atomically with the validated row.
-- Public editing and Agent permissions remain unchanged.
do $patch$
declare d text;guard text:=$guard$if old.archived_at is not null then raise exception 'This customer is archived. Restore it before editing.' using errcode='22023'; end if;$guard$;
begin
 d:=pg_get_functiondef('jioflow_private.jf_import_customer89(uuid,uuid,jsonb)'::regprocedure);
 if position('restore_import92' in d)=0 then
  if position(guard in d)=0 then raise exception 'Import helper changed; review before applying Update 92.';end if;
  d:=replace(d,guard,$restore$-- restore_import92: same shop and normalized phone, protected by existing advisory lock.
  if old.archived_at is not null then
   update public.jf_customers set archived_at=null,updated_at=now() where id=old.id and shop_id=target_shop;
  end if;$restore$);
  execute d;
 end if;
end $patch$;
revoke all on function jioflow_private.jf_import_customer89(uuid,uuid,jsonb) from public,anon,authenticated;
commit;
