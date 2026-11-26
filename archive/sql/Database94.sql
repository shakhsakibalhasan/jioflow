begin;
-- Only staff import entry points use this private helper. Ordinary editing is unchanged.
do $patch$
declare d text;anchor text:=$anchor$if jsonb_typeof(details)<>'object'$anchor$;
begin
 d:=pg_get_functiondef('jioflow_private.jf_import_customer89(uuid,uuid,jsonb)'::regprocedure);
 if position('optional_name94' in d)=0 then
  if position(anchor in d)=0 then raise exception 'Review changed import helper before applying Update 94.';end if;
  d:=replace(d,anchor,$new$-- optional_name94: serialize normalized phone before looking up a retained name.
 if jsonb_typeof(details)='object' then
  normalized:=jioflow_private.normalize_phone(details->>'phone');
  perform pg_advisory_xact_lock(hashtextextended(target_shop::text||normalized,0));
  select coalesce(jsonb_object_agg(key,value),'{}'::jsonb) into details from jsonb_each(details) where jsonb_typeof(value)<>'null' and (jsonb_typeof(value)<>'string' or btrim(value #>> '{}')<>'');
  if nullif(btrim(details->>'full_name'),'') is null then
   details:=jsonb_set(details,'{full_name}',to_jsonb(coalesce((select c.full_name from public.jf_customers c where c.shop_id=target_shop and c.phone=normalized),normalized)));
  end if;
 end if;
 if jsonb_typeof(details)<>'object'$new$);
  execute d;
 end if;
 d:=pg_get_functiondef('public.jf_history_import(uuid,text,jsonb)'::regprocedure);
 if position('optional_id94' in d)=0 then
  anchor:=$old$if length(trim(coalesce(r.payload->>'external_id',''))) not between 1 and 200$old$;
  if position(anchor in d)=0 then raise exception 'Review changed history importer before applying Update 94.';end if;
  d:=replace(d,anchor,$new$-- optional_id94: repeated identical no-ID rows receive the same stable ID.
    if nullif(trim(r.payload->>'external_id'),'') is null then
     r.payload:=jsonb_set(r.payload,'{external_id}',to_jsonb('AUTO-'||md5(jioflow_private.normalize_phone(r.payload->'customer'->>'phone')||':'||(r.payload-'customer'-'external_id'-'original_columns'-'updated_at')::text)));
    end if;
    if length(trim(coalesce(r.payload->>'external_id',''))) not between 1 and 200$new$);
  execute d;
 end if;
end $patch$;
revoke all on function jioflow_private.jf_import_customer89(uuid,uuid,jsonb) from public,anon,authenticated;
commit;
