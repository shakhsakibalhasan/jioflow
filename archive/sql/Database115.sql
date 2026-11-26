-- Update115: latest purchase SKU in existing guarded list projections.
begin;
do $patch$
declare fn record; definition text;
begin
 for fn in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','jioflow_private') and p.proname like 'jf_%' and p.prokind='f' loop
 definition:=pg_get_functiondef(fn.oid);
 if position('latest103 as materialized(select * from jioflow_private.jf_latest_order_status103(target_shop))' in definition)>0 then
 definition:=replace(definition,'latest103 as materialized(select * from jioflow_private.jf_latest_order_status103(target_shop))','latest103 as materialized(select customer_id,data->>''status'' as order_status,data->>''sku'' as latest_sku from jioflow_private.jf_latest_orders112(target_shop))');
 definition:=replace(definition,'ls.order_status as latest_order_status,','ls.order_status as latest_order_status,ls.latest_sku,');
 execute definition;
 end if;
 end loop;
end $patch$;
commit;
