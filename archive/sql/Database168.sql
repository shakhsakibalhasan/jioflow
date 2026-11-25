begin;
-- Keep exact assignment timestamps from installation onward; never infer old dates.
create table if not exists jioflow_private.jf_assignment_history168(
 id bigint generated always as identity primary key,shop_id uuid not null,customer_id uuid not null,
 membership_id uuid,created_at timestamptz not null default now());
revoke all on jioflow_private.jf_assignment_history168 from public,anon,authenticated;
create index if not exists jf_assignment_history168_period on jioflow_private.jf_assignment_history168(shop_id,created_at,customer_id);
create or replace function jioflow_private.jf_assignment_stamp168() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if (tg_op='INSERT' and new.assigned_membership_id is not null) or (tg_op='UPDATE' and new.assigned_membership_id is distinct from old.assigned_membership_id) then
 insert into jioflow_private.jf_assignment_history168(shop_id,customer_id,membership_id) values(new.shop_id,new.id,new.assigned_membership_id);end if;return new;
end $$;
revoke all on function jioflow_private.jf_assignment_stamp168() from public,anon,authenticated;
drop trigger if exists jf_assignment_stamp168 on public.jf_customers;
create trigger jf_assignment_stamp168 after insert or update of assigned_membership_id on public.jf_customers for each row execute function jioflow_private.jf_assignment_stamp168();
-- A customer activity period is creation, saved follow-up, native order or recorded assignment.
-- Imported historical order date remains an independent advanced filter.
create or replace function jioflow_private.jf_activity_customers168(target_shop uuid,report_start timestamptz,report_end timestamptz)
returns table(customer_id uuid) language sql stable security definer set search_path='' as $$
 select c.id from public.jf_customers c where c.shop_id=target_shop and c.created_at>=coalesce(report_start,'-infinity') and c.created_at<coalesce(report_end,'infinity')
 union select f.customer_id from public.jf_followups f where f.shop_id=target_shop and f.last_contact_at>=coalesce(report_start,'-infinity') and f.last_contact_at<coalesce(report_end,'infinity')
 union select f.customer_id from public.jf_followup_events e join public.jf_followups f on f.shop_id=e.shop_id and f.id=e.followup_id where e.shop_id=target_shop and e.actor_id is not null and e.created_at>=coalesce(report_start,'-infinity') and e.created_at<coalesce(report_end,'infinity')
 union select o.customer_id from public.jf_orders o where o.shop_id=target_shop and o.archived_at is null and o.created_at>=coalesce(report_start,'-infinity') and o.created_at<coalesce(report_end,'infinity')
 union select a.customer_id from jioflow_private.jf_assignment_history168 a where a.shop_id=target_shop and a.created_at>=coalesce(report_start,'-infinity') and a.created_at<coalesce(report_end,'infinity');
$$;
revoke all on function jioflow_private.jf_activity_customers168(uuid,timestamptz,timestamptz) from public,anon,authenticated;
create index if not exists jf_followup_events_period168 on public.jf_followup_events(shop_id,created_at,followup_id) where actor_id is not null;
create index if not exists jf_followups_contact168 on public.jf_followups(shop_id,last_contact_at,customer_id);
-- Apply activity periods to every customer-list implementation, retaining existing access guards.
do $patch$
declare r record;d text;needle text:='c.archived_at is null';addition text:=$add$c.archived_at is null and (/*activity168*/ (nullif(filters->>'report_start','') is null and nullif(filters->>'report_end','') is null) or c.id in(select customer_id from jioflow_private.jf_activity_customers168(target_shop,nullif(filters->>'report_start','')::timestamptz,nullif(filters->>'report_end','')::timestamptz))) and (st<>'confirmed' or (nullif(filters->>'report_start','') is null and nullif(filters->>'report_end','') is null) or exists(select 1 from public.jf_orders period168 where period168.shop_id=target_shop and period168.customer_id=c.id and period168.archived_at is null and period168.status not in('draft','cancelled') and period168.created_at>=coalesce(nullif(filters->>'report_start','')::timestamptz,'-infinity') and period168.created_at<coalesce(nullif(filters->>'report_end','')::timestamptz,'infinity')))$add$;
begin
 for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname in('jf_agent_page78','jf_workspace_page_rls73','jf_workspace_page_staff73') loop
 d:=pg_get_functiondef(r.oid);if position('activity168' in d)=0 then
 if position(needle in d)=0 then raise exception 'Customer-list patch target missing: %',r.oid::regprocedure;end if;
 d:=replace(d,needle,addition);execute d;end if;end loop;
end $patch$;
-- Saved status activity is independent of customer creation and order dates.
create or replace function jioflow_private.jf_contact_customers168(target_shop uuid,report_start timestamptz,report_end timestamptz)
returns table(customer_id uuid) language sql stable security definer set search_path='' as $$
 select f.customer_id from public.jf_followups f where f.shop_id=target_shop and f.last_contact_at>=coalesce(report_start,'-infinity') and f.last_contact_at<coalesce(report_end,'infinity')
 union select f.customer_id from public.jf_followup_events e join public.jf_followups f on f.shop_id=e.shop_id and f.id=e.followup_id where e.shop_id=target_shop and e.actor_id is not null and e.created_at>=coalesce(report_start,'-infinity') and e.created_at<coalesce(report_end,'infinity');
$$;
revoke all on function jioflow_private.jf_contact_customers168(uuid,timestamptz,timestamptz) from public,anon,authenticated;
do $completion$
declare r record;d text;expr text;begin
 for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname in('jf_agent_page78','jf_workspace_page_rls73','jf_workspace_page_staff73') loop
 d:=pg_get_functiondef(r.oid);if position('contact168' in d)=0 then
 foreach expr in array array['public.jf_followup_done139(c.followup_status,c.call_outcome)','public.jf_followup_done139(followup_status,call_outcome)'] loop
 d:=replace(d,expr,'('||expr||$contact$ and (/*contact168*/ (nullif(filters->>'report_start','') is null and nullif(filters->>'report_end','') is null) or $contact$||case when expr like '%(c.%' then 'c.id' else 'id' end||$contact$ in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,nullif(filters->>'report_start','')::timestamptz,nullif(filters->>'report_end','')::timestamptz))))$contact$);
 end loop;execute d;end if;end loop;
end $completion$;
-- Summary customer counters use the same activity cohort; orders retain created-at period.
do $summary$
declare d text;needle text:='c.archived_at is null';begin
 d:=pg_get_functiondef('public.jf_workspace_summary(uuid,timestamptz,timestamptz)'::regprocedure);
 if position('activity168' in d)=0 then
 if position(needle in d)=0 then raise exception 'Summary patch target missing';end if;
 d:=replace(d,'f.customer_id=c.id','f.customer_id=c.id and ((report_start is null and report_end is null) or c.id in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,report_start,report_end)))');
 d:=replace(d,needle,'c.archived_at is null and (/*activity168*/ (report_start is null and report_end is null) or c.id in(select customer_id from jioflow_private.jf_activity_customers168(target_shop,report_start,report_end)))');execute d;end if;
end $summary$;
-- Agent overview and supervised dashboard share the same period cohort.
do $agents$
declare r record;d text;begin
 for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname='jioflow_private' and p.proname='jf_agent_report_base155') or (n.nspname='public' and p.proname='jf_agent_workspace_summary') loop
 d:=pg_get_functiondef(r.oid);if position('activity168' in d)=0 then
 d:=replace(d,'f.customer_id=c.id','f.customer_id=c.id and ((report_start is null and report_end is null) or c.id in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,report_start,report_end)))');
 d:=replace(d,'c.archived_at is null','c.archived_at is null and (/*activity168*/ (report_start is null and report_end is null) or c.id in(select customer_id from jioflow_private.jf_activity_customers168(target_shop,report_start,report_end)))');execute d;end if;end loop;
end $agents$;
-- KPI155 overrides the older summary. Its customer cohort and Confirm must also respect the period.
do $kpi$
declare d text;begin
 d:=pg_get_functiondef('public.jf_dashboard_kpi155(uuid,uuid,timestamptz,timestamptz)'::regprocedure);
 if position('activity168' in d)=0 then
 d:=replace(d,'c.archived_at is null','c.archived_at is null and (/*activity168*/ (report_start is null and report_end is null) or c.id in(select customer_id from jioflow_private.jf_activity_customers168(target_shop,report_start,report_end)))');
 d:=replace(d,'where public.jf_followup_done139(saved_status,call_outcome)','where public.jf_followup_done139(saved_status,call_outcome) and ((report_start is null and report_end is null) or id in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,report_start,report_end)))');
 d:=replace(d,'where not public.jf_followup_done139(saved_status,call_outcome)','where not (public.jf_followup_done139(saved_status,call_outcome) and ((report_start is null and report_end is null) or id in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,report_start,report_end))))');
 d:=replace(d,'select o.id from public.jf_orders o','select o.id,o.customer_id,o.status from public.jf_orders o');
 d:=replace(d,'from customers where workflow_label=any(labels)','from customers c where workflow_label=any(labels) and exists(select 1 from orders o where o.customer_id=c.id and o.status not in(''draft'',''cancelled''))');
 execute d;end if;
end $kpi$;
commit;
