begin;
-- Retain the customer details supplied on each purchase; the phone profile is still shared.
do $patch$
declare d text;old text:=$old$values(target_shop,cid,trim(r.payload->>'external_id'),r.payload-'customer'-'external_id') on conflict$old$;
begin
 d:=pg_get_functiondef('public.jf_history_import(uuid,text,jsonb)'::regprocedure);
 if position('customer_snapshot105' in d)=0 then
  if position(old in d)=0 then raise exception 'Import function changed; review before applying Update105.';end if;
  d:=replace(d,old,$new$values(target_shop,cid,trim(r.payload->>'external_id'),(r.payload-'customer'-'external_id')||jsonb_build_object('customer_snapshot105',r.payload->'customer')) on conflict$new$);
  execute d;
 end if;
end $patch$;
commit;
