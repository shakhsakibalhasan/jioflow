begin;
-- Repair imported dates only where original uploaded columns are retained.
-- Never substitute upload time or Created At for Order Date.
update public.jf_order_history h set details=jsonb_set(h.details,'{ordered_at}',to_jsonb(coalesce((select x->>'value' from jsonb_array_elements(h.details->'original_columns') with ordinality as t(x,n) where lower(regexp_replace(x->>'column','[^a-zA-Z0-9]','','g')) in('orderdate','orderedat','date') order by n limit 1),'')))
where jsonb_typeof(h.details->'original_columns')='array';
-- Keep the existing permission guards and role-specific query scopes intact.
do $patch$
declare r record;d text;changed text;
begin
 for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.prokind='f' and p.proname like 'jf_%' loop
  d:=pg_get_functiondef(r.oid);
  changed:=replace(d,$old$coalesce(h.details->>'ordered_at',h.details->>'order_date',h.details->>'created_at')$old$,$new$coalesce(nullif(h.details->>'ordered_at',''),h.details->>'order_date')$new$);
  if changed<>d then execute changed;end if;
 end loop;
end $patch$;
commit;
