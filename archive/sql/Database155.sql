begin;
-- Every explicit saved status is completed, including Processing with no call response.
do $patch$
declare d text;begin
 d:=pg_get_functiondef('public.jf_followup_outcomes130(uuid,uuid,text,timestamp with time zone,text,text,text)'::regprocedure);
 if position('completed155' in d)=0 then
 d:=replace(d,'return fid;',E'/*completed155*/ update public.jf_followups set status=''completed'' where id=fid and status=''pending'' and coalesce(call_outcome,''not_attempted'')=''not_attempted'';\n return fid;');execute d;
 end if;
end $patch$;
-- Cover the legacy explicit follow-up form too; imports do not call this save action.
do $record$
declare d text;begin
 d:=pg_get_functiondef('public.jf_record_followup(uuid,uuid,text,text,timestamptz,text)'::regprocedure);
 if position('completed155' in d)=0 then
 d:=replace(d,'return fid;',E'/*completed155*/ update public.jf_followups set status=''completed'' where id=fid and status=''pending'' and coalesce(call_outcome,''not_attempted'')=''not_attempted'';\n return fid;');execute d;end if;
end $record$;
-- Repair only rows with a recorded explicit interaction; untouched imported/default rows stay Pending.
update public.jf_followups f set status='completed'
where f.status='pending' and coalesce(f.call_outcome,'not_attempted')='not_attempted' and f.last_contact_at is not null
and exists(select 1 from public.jf_followup_events e where e.shop_id=f.shop_id and e.followup_id=f.id and e.actor_id is not null);
create or replace function public.jf_dashboard_kpi155(target_shop uuid,target_agent uuid default null,report_start timestamptz default null,report_end timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare staff boolean;mid uuid;labels text[];answer jsonb;begin
 staff:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);mid:=jioflow_private.agent_member(target_shop);
 if not coalesce(jioflow_private.session_allowed(),false) or (not staff and mid is null) or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null) then raise exception 'Workspace access required.' using errcode='42501';end if;
 if not staff then if target_agent is not null and target_agent<>mid then raise exception 'Agent scope denied.' using errcode='42501';end if;target_agent:=mid;end if;
 if target_agent is not null and not exists(select 1 from public.jf_memberships where id=target_agent and shop_id=target_shop) then raise exception 'Choose an Agent in this business.';end if;
 labels:=jioflow_private.confirmed_labels149(target_shop);
 with customers as(select c.*,f.status saved_status,f.call_outcome from public.jf_customers c left join public.jf_followups f on f.shop_id=c.shop_id and f.customer_id=c.id where c.shop_id=target_shop and c.archived_at is null and (target_agent is null or c.assigned_membership_id=target_agent)),
 orders as(select o.id from public.jf_orders o where o.shop_id=target_shop and o.archived_at is null and (target_agent is null or o.assigned_membership_id=target_agent or not staff and o.entered_by=auth.uid()) and (report_start is null or o.created_at>=report_start) and (report_end is null or o.created_at<report_end))
 select jsonb_build_object('confirmed_customers',(select count(*) from customers where workflow_label=any(labels)),'completed',(select count(*) from customers where public.jf_followup_done139(saved_status,call_outcome)),'pending',(select count(*) from customers where not public.jf_followup_done139(saved_status,call_outcome)),
 'orders_created',(select count(*) from orders),'booked155',(select count(*) from orders o where exists(select 1 from public.jf_shipments s where s.shop_id=target_shop and s.order_id=o.id and s.booked_at is not null))) into answer;
 return answer;
end $$;
revoke all on function public.jf_dashboard_kpi155(uuid,uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.jf_dashboard_kpi155(uuid,uuid,timestamptz,timestamptz) to authenticated;
-- Booked card opens all successfully booked orders, even if delivery later advances.
do $pages$
declare f record;d text;begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname in('jf_agent_page78','jf_workspace_page_rls73','jf_workspace_page_staff73') loop
 d:=pg_get_functiondef(f.oid);
 if position('booked_ever155' in d)=0 then
 d:=replace(d,$old$matching as(select * from entries where st='all'$old$,$new$matching as(select * from entries where (st='booked_ever155' and exists(select 1 from public.jf_shipments bs155 where bs155.shop_id=target_shop and bs155.order_id=(entry->>'id')::uuid and bs155.booked_at is not null)) or st='all'$new$);
 execute d;end if;
 end loop;
end $pages$;
-- Retain the existing Agent Report guard, enrich its Agent rows with the same KPI rules.
do $report$
declare d text;begin
 if to_regprocedure('jioflow_private.jf_agent_report_base155(uuid,uuid,timestamptz,timestamptz)') is null then
 d:=pg_get_functiondef('public.jf_agent_report(uuid,uuid,timestamptz,timestamptz)'::regprocedure);
 d:=replace(d,'public.jf_agent_report(','jioflow_private.jf_agent_report_base155(');execute d;
 end if;
end $report$;
revoke all on function jioflow_private.jf_agent_report_base155(uuid,uuid,timestamptz,timestamptz) from public,anon,authenticated;
create or replace function public.jf_agent_report(target_shop uuid,target_agent uuid default null,report_start timestamptz default null,report_end timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare base jsonb;begin
 base:=jioflow_private.jf_agent_report_base155(target_shop,target_agent,report_start,report_end);
 return jsonb_set(base,'{agents}',coalesce((select jsonb_agg(a.value||public.jf_dashboard_kpi155(target_shop,(a.value->>'id')::uuid,report_start,report_end) order by a.ordinality) from jsonb_array_elements(coalesce(base->'agents','[]'::jsonb)) with ordinality a(value,ordinality)),'[]'::jsonb));
end $$;
revoke all on function public.jf_agent_report(uuid,uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.jf_agent_report(uuid,uuid,timestamptz,timestamptz) to authenticated;
create or replace function jioflow_private.jf_mark_changed152() returns trigger language plpgsql security definer set search_path='' as $$
declare scope_query text;relation_query text;begin
 -- Skip timestamp/lease-only UPDATEs so background polling cannot trigger redraw loops.
 if tg_op='UPDATE' then
 if not exists(select 1 from new152 n full join old152 o on coalesce(to_jsonb(n)->>'id',to_jsonb(n)->>'session_id',to_jsonb(n)->>'shop_id')=coalesce(to_jsonb(o)->>'id',to_jsonb(o)->>'session_id',to_jsonb(o)->>'shop_id') where
 (to_jsonb(n)-array['updated_at','last_seen','last_seen_at','last_checked_at','last_synced_at','booking_lease_until','poll_lease_until']) is distinct from
 (to_jsonb(o)-array['updated_at','last_seen','last_seen_at','last_checked_at','last_synced_at','booking_lease_until','poll_lease_until'])) then return null;end if;
 end if;
 relation_query:=case tg_op when 'INSERT' then 'select to_jsonb(n) data from new152 n' when 'DELETE' then 'select to_jsonb(o) data from old152 o' else 'select to_jsonb(n) data from new152 n union all select to_jsonb(o) data from old152 o' end;
 if tg_table_name='jf_agent_sessions' and tg_op='UPDATE' then relation_query:='select to_jsonb(n) data from new152 n where not exists(select 1 from old152 o where coalesce(to_jsonb(o)->>''session_id'',to_jsonb(o)->>''id'')=coalesce(to_jsonb(n)->>''session_id'',to_jsonb(n)->>''id'') and to_jsonb(o)->>''status''=to_jsonb(n)->>''status'')';end if;
 if tg_table_name='jf_profiles' then scope_query:='select distinct m.shop_id from ('||relation_query||') r join public.jf_memberships m on m.user_id=(r.data->>''id'')::uuid';
 elsif tg_table_name='jf_shops' then scope_query:='select distinct (r.data->>''id'')::uuid shop_id from ('||relation_query||') r';
 else scope_query:='select distinct (r.data->>''shop_id'')::uuid shop_id from ('||relation_query||') r';end if;
 execute 'insert into jioflow_private.jf_changes152 as t(shop_id,bucket,version) select s.shop_id,$1,$2 from ('||scope_query||') s where s.shop_id is not null on conflict(shop_id,bucket) do update set version=excluded.version where t.version<>excluded.version' using tg_argv[0],txid_current();
 return null;
end $$;

create index if not exists jf_shipment_booked155 on public.jf_shipments(shop_id,order_id) where booked_at is not null;
commit;
