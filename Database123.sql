begin;
-- Default Agent work rights are scoped by existing customer/order ownership checks.
-- Do not grant the global assign permission (which also controls redistribution).
do $patch$
declare fn record;d text;
begin
 for fn in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' and (p.proname in('jf_save_customer','jf_record_followup','jf_followup_status','jf_customer_note103','jf_update_order','jf_edit_order_products') or p.proname like 'jf_save_order%') loop
 d:=pg_get_functiondef(fn.oid);
 d:=replace(d,'not jioflow_private.has_permission(target_shop,''assign'')','not (jioflow_private.has_permission(target_shop,''assign'') or jioflow_private.agent_member(target_shop) is not null)');
 d:=replace(d,'not coalesce(jioflow_private.has_permission(target_shop,''assign''),false)','not (coalesce(jioflow_private.has_permission(target_shop,''assign''),false) or jioflow_private.agent_member(target_shop) is not null)');
 execute d;
 end loop;
end $patch$;
commit;
