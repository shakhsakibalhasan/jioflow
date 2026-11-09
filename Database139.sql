begin;
-- Follow-up completion is an attempted/saved interaction, independent of
-- confirmation, courier state and the selected workflow label.
create or replace function public.jf_followup_done139(saved_status text,saved_outcome text)
returns boolean language sql immutable security invoker set search_path='' as $$
 select coalesce(saved_status='completed' or nullif(saved_outcome,'not_attempted') is not null,false)
$$;
revoke all on function public.jf_followup_done139(text,text) from public,anon;
grant execute on function public.jf_followup_done139(text,text) to authenticated;
do $patch$
declare r record;d text;begin
 for r in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in('public','jioflow_private') and p.prokind='f' and
 (p.proname in('jf_agent_report','jf_workspace_summary','jf_agent_workspace_summary','jf_agent_page78','jf_selection_rls74','jf_selection_staff74','jf_workspace_page_rls73','jf_workspace_page_staff73')) loop
 d:=pg_get_functiondef(r.oid);
 -- Keep the Confirmed bucket tied to the actual workflow, never all completions.
 d:=replace(d,$s$st='confirmed' and c.followup_status='completed'$s$,$s$st='confirmed' and c.workflow_label='Confirm'$s$);
 d:=replace(d,$s$'confirmed',count(*) filter(where followup_status='completed')$s$,$s$'confirmed',count(*) filter(where workflow_label='Confirm')$s$);
 d:=replace(d,$s$coalesce(c.followup_status,'pending') in ('pending','callback')$s$,$s$not public.jf_followup_done139(c.followup_status,c.call_outcome)$s$);
 d:=replace(d,$s$coalesce(followup_status,'pending') in('pending','callback')$s$,$s$not public.jf_followup_done139(followup_status,call_outcome)$s$);
 d:=replace(d,$s$coalesce(followup_status,'pending') in ('pending','callback')$s$,$s$not public.jf_followup_done139(followup_status,call_outcome)$s$);
 d:=replace(d,$s$coalesce(f.status,'pending') in('pending','callback')$s$,$s$not public.jf_followup_done139(f.status,f.call_outcome)$s$);
 d:=replace(d,$s$c.followup_status='completed'$s$,$s$public.jf_followup_done139(c.followup_status,c.call_outcome)$s$);
 d:=replace(d,$s$where followup_status='completed'$s$,$s$where public.jf_followup_done139(followup_status,call_outcome)$s$);
 d:=replace(d,$s$f.status='completed'$s$,$s$public.jf_followup_done139(f.status,f.call_outcome)$s$);
 if d<>pg_get_functiondef(r.oid) then execute d;end if;
 end loop;
end$patch$;
commit;
