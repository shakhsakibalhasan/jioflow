begin;
-- Exclude permanent profiles from the Agent Assigned Customers branch before counts/pagination.
-- The existing shop/session/assignment security checks are preserved.
do $patch$
declare fn record;d text;begin
 for fn in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.prokind='f' and n.nspname in('public','jioflow_private') and p.proname in('jf_workspace_page_staff73','jf_workspace_page_rls73','jf_workspace_page_fast_rls73','jf_agent_page78','jf_selection_customers75') loop
 d:=pg_get_functiondef(fn.oid);
 if position('_exclude_permanent134' in d)=0 then
 d:=replace(d,'where c.shop_id=target_shop and c.archived_at is null','where c.shop_id=target_shop and c.archived_at is null and (coalesce(filters->>''_exclude_permanent134'',''false'')<>''true'' or not c.permanent)');
 if d<>pg_get_functiondef(fn.oid) then execute d;end if;
 end if;
 end loop;
end $patch$;
commit;
