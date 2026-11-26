begin;
-- Explicit access checks: no dependency on formatting of an older function.
create or replace function public.jf_followup_status(target_shop uuid,customer_id uuid,status_label text,callback_time timestamptz default null,note_text text default '') returns uuid language plpgsql security definer set search_path='' as $fn$
declare fid uuid;next_status text:='pending';outcome text:='intermediate';definition jsonb;days integer;
begin
 if not coalesce(jioflow_private.session_allowed(),false)
 or not (coalesce(jioflow_private.has_permission(target_shop,'assign'),false) or jioflow_private.agent_member(target_shop) is not null)
 or not coalesce(jioflow_private.can_read_customer(target_shop,customer_id),false)
 or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null)
 then raise exception 'Follow-up access denied.' using errcode='42501';end if;
 select x into definition from jsonb_array_elements(case when (select c.permanent from public.jf_customers c where c.shop_id=target_shop and c.id=customer_id) then jioflow_private.permanent_status_definitions(target_shop) else jioflow_private.status_definitions(target_shop) end) x where x->>'name'=status_label and (x->>'active')::boolean;
 if definition is null then raise exception 'Choose an active follow-up status.';end if;
 perform 1 from public.jf_customers c where c.shop_id=target_shop and c.id=customer_id and c.archived_at is null for update;
 if not found then raise exception 'Customer not found.';end if;
 case definition->>'kind'
 when 'confirm' then next_status:='completed';outcome:='positive';
 when 'negative' then next_status:='cancelled';outcome:='negative';
 when 'positive' then outcome:='positive';
 when 'no_answer' then outcome:='no_answer';
 when 'busy' then outcome:='busy';
 when 'schedule' then next_status:='callback';outcome:='connected';days:=coalesce((definition->>'days')::integer,0);if days>0 and callback_time is null then callback_time:=now()+days*interval '1 day';end if;
 else null;end case;
 if next_status='callback' and callback_time is null then raise exception 'Select a callback date and time.';end if;
 fid:=public.jf_record_followup(target_shop,customer_id,next_status,outcome,callback_time,note_text);
 update public.jf_customers c set workflow_label=status_label,updated_at=now() where c.shop_id=target_shop and c.id=customer_id;
 return fid;
end $fn$;
revoke all on function public.jf_followup_status(uuid,uuid,text,timestamptz,text) from public,anon;
grant execute on function public.jf_followup_status(uuid,uuid,text,timestamptz,text) to authenticated;
-- Namespaced exact labels prevent collisions with Pending, Completed and call outcome filters.
do $patch$
declare f record;d text;begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname in('jf_agent_page78','jf_workspace_page_rls73','jf_workspace_page_staff73','jf_selection_rls74','jf_selection_staff74') loop
 d:=pg_get_functiondef(f.oid);
 if position('workflow142:' in d)>0 then continue;end if;
 d:=replace(d,'lower(replace(c.workflow_label,'' '',''_''))=st','(''workflow142:''||encode(convert_to(c.workflow_label,''UTF8''),''hex''))=st or lower(replace(c.workflow_label,'' '',''_''))=st');
 -- Keep ordinary aggregate keys and add an independent exact-label count map.
 d:=replace(d,'select lower(replace(workflow_label,'' '',''_'')) k,count(*) n from base','select ''workflow142:''||encode(convert_to(workflow_label,''UTF8''),''hex'') k,count(*) n from base');
 if d<>pg_get_functiondef(f.oid) then execute d;end if;
 end loop;
end $patch$;
-- Keep Confirm reporting tied to its configured behavior after a rename.
create or replace function jioflow_private.confirmed_workflow142(target_shop uuid,label text) returns boolean language sql stable security definer set search_path='' as $fn$
 select exists(select 1 from jsonb_array_elements(jioflow_private.status_definitions(target_shop)||jioflow_private.permanent_status_definitions(target_shop)) x where x->>'name'=label and x->>'kind'='confirm' and (x->>'active')::boolean)
$fn$;
revoke all on function jioflow_private.confirmed_workflow142(uuid,text) from public,anon,authenticated;
do $patch$
declare f record;d text;begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname in('jf_agent_report','jf_workspace_summary','jf_agent_workspace_summary','jf_agent_page78','jf_selection_rls74','jf_selection_staff74','jf_workspace_page_rls73','jf_workspace_page_staff73') loop
 d:=pg_get_functiondef(f.oid);
 d:=replace(d,'c.workflow_label=''Confirm''','jioflow_private.confirmed_workflow142(target_shop,c.workflow_label)');
 d:=replace(d,'workflow_label=''Confirm''','jioflow_private.confirmed_workflow142(target_shop,workflow_label)');
 if d<>pg_get_functiondef(f.oid) then execute d;end if;
 end loop;
end $patch$;
commit;
