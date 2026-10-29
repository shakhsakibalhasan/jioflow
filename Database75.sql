begin;
create or replace function public.jf_page_size75(filters jsonb) returns integer language sql immutable security invoker set search_path='' as $$
 select case coalesce(filters->>'_page_size','') when '20' then 20 when '50' then 50 when '100' then 100 when '200' then 200 else 50 end;
$$;
revoke all on function public.jf_page_size75(jsonb) from public,anon;
grant execute on function public.jf_page_size75(jsonb) to authenticated;
do $patch$ declare f record;body text;begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname in('jf_workspace_page','jf_workspace_page_fast','jf_workspace_page_rls73','jf_workspace_page_staff73','jf_workspace_page_fast_rls73','jf_workspace_page_fast_staff73') loop
 body:=pg_get_functiondef(f.oid);
 body:=replace(body,'limit 50 offset page_number::bigint*50','limit public.jf_page_size75(filters) offset page_number::bigint*public.jf_page_size75(filters)');
 body:=replace(body,'''status'',''search'',''agent_id'',''source'',''tag'',''_fast''','''status'',''search'',''agent_id'',''source'',''tag'',''_fast'',''_page_size''');
 execute body;
 end loop;
end $patch$;
insert into public.jf_schema_versions(version) values('053_followup_pagination') on conflict do nothing;
commit;
