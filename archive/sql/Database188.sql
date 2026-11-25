begin;
-- Exact fixed Assigned partitions; all existing visibility and date/search guards remain.
do $patch$ declare r record;d text;a int;b int;body text;begin
for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname in('jf_agent_page78','jf_workspace_page_rls73','jf_workspace_page_staff73') loop
 d:=pg_get_functiondef(r.oid);if position('/*assigned188*/' in d)>0 then continue;end if;
 a:=position($m$ if entity='customers' then$m$ in d);b:=position($m$elsif entity='orders' then$m$ in d);if a=0 or b<=a then raise exception 'Customer branch missing';end if;body:=substring(d from a for b-a);
 body:=replace(body,$x$filters->>'_bucket171'='completed' and$x$,$x$filters->>'_bucket171'='completed' and (c.assigned_membership_id is null or not jioflow_private.jf_unworked176(target_shop,c.id)) and$x$);
 body:=replace(body,$x$'completed',count(*) filter(where (public.jf_followup_done139(followup_status,call_outcome)$x$,$x$'completed',count(*) filter(where ((assigned_membership_id is null or not jioflow_private.jf_unworked176(target_shop,id)) and public.jf_followup_done139(followup_status,call_outcome)$x$);
 body:=replace(body,'c as(select * from base c where (', $x$c as(select * from base c where (/*assigned188*/ st='processing188' and c.assigned_membership_id is not null and jioflow_private.jf_unworked176(target_shop,c.id) or st='completed188' and c.assigned_membership_id is not null and not jioflow_private.jf_unworked176(target_shop,c.id) or $x$);
 body:=replace(body,$x$'processing176',count(*) filter(where assigned_membership_id is not null and jioflow_private.jf_unworked176(target_shop,id))$x$,$x$'processing176',count(*) filter(where assigned_membership_id is not null and jioflow_private.jf_unworked176(target_shop,id)),'completed188',count(*) filter(where assigned_membership_id is not null and not jioflow_private.jf_unworked176(target_shop,id))$x$);
 if position('/*assigned188*/' in body)=0 or position($x$'completed188',count(*)$x$ in body)=0 then raise exception 'Assigned patch incomplete';end if;
 execute left(d,a-1)||body||substring(d from b);
end loop;end $patch$;
create or replace function public.jf_followup_page171(target_shop uuid,entity text,filters jsonb default '{}',page_number int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare bucket text:=coalesce(filters->>'group171','unassigned');sub text:=coalesce(filters->>'sub171','never');f jsonb;result jsonb;global_counts jsonb;begin
 if entity<>'customers' then raise exception 'Follow-up tabs apply to customers only.';end if;
 if not coalesce(jioflow_private.session_allowed(),false) then raise exception 'Workspace access required.' using errcode='42501';end if;
 if bucket not in('all','assigned','unassigned','completed','permanent') or length(sub)>160 then raise exception 'Invalid Follow-up selection.';end if;
 f:=(coalesce(filters,'{}')-array['group171','sub171','_never171','tag','_processing176'])||jsonb_build_object('_bucket171',bucket,'status','all');
 if bucket='unassigned' then
 if sub='never' then f:=f||jsonb_build_object('status','never_assigned171');
 elsif sub<>'all' then f:=f||jsonb_build_object('status','tag171:'||encode(convert_to(sub,'UTF8'),'hex'));end if;
 elsif bucket='assigned' then if sub in('processing176','processing188') then f:=f||jsonb_build_object('status','processing188');elsif sub='completed188' then f:=f||jsonb_build_object('status','completed188');end if;
 elsif sub<>'all' then f:=f||jsonb_build_object('status','workflow142:'||encode(convert_to(sub,'UTF8'),'hex'));end if;
 if coalesce(filters->>'_fast','false')='true' then return public.jf_workspace_page_fast(target_shop,entity,f,page_number);end if;
 result:=public.jf_workspace_page(target_shop,entity,f,page_number);
 result:=result||jsonb_build_object('sub_counts171',result->'counts');
 global_counts:=result->'primary_counts181';result:=result-'primary_counts181';
 return result||jsonb_build_object('primary_counts171',global_counts);
end$$;
revoke all on function public.jf_followup_page171(uuid,text,jsonb,int) from public,anon;
grant execute on function public.jf_followup_page171(uuid,text,jsonb,int) to authenticated;
CREATE OR REPLACE FUNCTION public.jf_dashboard_kpi155(target_shop uuid, target_agent uuid DEFAULT NULL::uuid, report_start timestamp with time zone DEFAULT NULL::timestamp with time zone, report_end timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare staff boolean;mid uuid;labels text[];answer jsonb;begin
 staff:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);mid:=jioflow_private.agent_member(target_shop);
 if not coalesce(jioflow_private.session_allowed(),false) or (not staff and mid is null) or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null) then raise exception 'Workspace access required.' using errcode='42501';end if;
 if not staff then if target_agent is not null and target_agent<>mid then raise exception 'Agent scope denied.' using errcode='42501';end if;target_agent:=mid;end if;
 if target_agent is not null and not exists(select 1 from public.jf_memberships where id=target_agent and shop_id=target_shop) then raise exception 'Choose an Agent in this business.';end if;
 labels:=jioflow_private.confirmed_labels149(target_shop);
 with customers as(select c.*,f.status saved_status,f.call_outcome,f.last_contact_at from public.jf_customers c left join public.jf_followups f on f.shop_id=c.shop_id and f.customer_id=c.id where c.shop_id=target_shop and c.archived_at is null and (/*activity168*/ (report_start is null and report_end is null) or c.id in(select customer_id from jioflow_private.jf_activity_customers168(target_shop,report_start,report_end))) and (target_agent is null or c.assigned_membership_id=target_agent)),
 orders as(select o.id,o.customer_id,o.status from public.jf_orders o where o.shop_id=target_shop and o.archived_at is null and (target_agent is null or o.assigned_membership_id=target_agent or not staff and o.entered_by=auth.uid()) and (report_start is null or o.created_at>=report_start) and (report_end is null or o.created_at<report_end))
 select jsonb_build_object('confirmed_customers',(select count(*) from customers c where workflow_label=any(labels) and exists(select 1 from orders o where o.customer_id=c.id and o.status not in('draft','cancelled'))),'completed',(select count(*) from customers where (public.jf_followup_done139(saved_status,call_outcome) and (assigned_membership_id is null or not jioflow_private.jf_unworked176(target_shop,id))) and ((report_start is null and report_end is null) or id in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,report_start,report_end)))),'pending',(select count(*) from customers where not ((public.jf_followup_done139(saved_status,call_outcome) and (assigned_membership_id is null or not jioflow_private.jf_unworked176(target_shop,id))) and ((report_start is null and report_end is null) or id in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,report_start,report_end))))),
 /*purchase188*/ 'processing188',(select count(*) from customers where assigned_membership_id is not null and jioflow_private.jf_unworked176(target_shop,id)),
 'buyers',(select count(*) from customers c where public.jf_followup_done139(saved_status,call_outcome) and (assigned_membership_id is null or not jioflow_private.jf_unworked176(target_shop,c.id)) and ((report_start is null and report_end is null) or c.id in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,report_start,report_end))) and exists(select 1 from orders o where o.customer_id=c.id and o.status not in('draft','cancelled','imported'))),
 'orders_created',(select count(*) from orders),'booked155',(select count(*) from orders o where exists(select 1 from public.jf_shipments s where s.shop_id=target_shop and s.order_id=o.id and s.booked_at is not null))) into answer;
 return answer||jsonb_build_object('purchase_rate',case when (answer->>'completed')::numeric>0 then 100.0*(answer->>'buyers')::numeric/(answer->>'completed')::numeric else 0 end);
end $function$
;
CREATE OR REPLACE FUNCTION public.jf_prepare_password_set(target_user uuid DEFAULT NULL::uuid, reset_request uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=target_user;p public.jf_profiles%rowtype;r public.jf_password_requests%rowtype;m public.jf_memberships%rowtype;lid uuid;
begin
 if not jioflow_private.session_allowed() then raise exception 'Sign in again.' using errcode='42501';end if;
 if reset_request is not null then
  select * into r from public.jf_password_requests where id=reset_request for update;
  if not found or r.status not in('pending','approved') or (r.status='approved' and r.expires_at<=now()) or (uid is not null and uid<>r.user_id) then raise exception 'This reset request is closed.' using errcode='42501';end if;uid:=r.user_id;
 end if;
 if exists(select 1 from public.jf_shops where owner_id=uid) or exists(select 1 from public.jf_memberships where user_id=uid and role='owner' and status<>'removed') then raise exception 'Owner password changes require email verification.' using errcode='42501';end if;
 select * into p from public.jf_profiles where id=uid for update;
 if not found or not p.active or p.deleted_at is not null or p.platform_role='creator' or uid=auth.uid() or not(jioflow_private.is_creator() or jioflow_private.can_manage_lower(uid,'users')) then raise exception 'Password reset access denied.' using errcode='42501';end if;
 if (select count(*) from jioflow_private.account_audit where actor_id=auth.uid() and action='prepare_password_set' and created_at>now()-interval '1 minute')>=5 then raise exception 'Wait a minute before resetting more passwords.';end if;
 if exists(select 1 from jioflow_private.password_set_leases where user_id=uid and finished_at is null and cancelled_at is null and expires_at>now()) then raise exception 'A password reset is already in progress.';end if;
 select * into m from public.jf_memberships where user_id=uid and role='agent' and status in('active','pending') order by created_at limit 1;
 if found then
  if not exists(select 1 from public.jf_shops where id=m.shop_id and active and paused_at is null) then raise exception 'Workspace access is disabled.' using errcode='42501';end if;
  if reset_request is null then select * into r from public.jf_password_requests where user_id=uid and status='pending' for update;end if;
  if r.id is null then insert into public.jf_password_requests(user_id,shop_id) values(uid,m.shop_id) returning * into r;end if;
  if r.shop_id<>m.shop_id then raise exception 'Agent business changed.' using errcode='42501';end if;
  update public.jf_password_requests set status='approved',decided_by=auth.uid(),decided_at=now(),expires_at=now()+interval '2 minutes' where id=r.id;
 elsif reset_request is not null then raise exception 'Agent access changed.' using errcode='42501';end if;
 insert into jioflow_private.password_set_leases(actor_id,user_id,request_id) values(auth.uid(),uid,r.id) returning id into lid;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),uid,'prepare_password_set',jsonb_build_object('request_id',r.id));
 return jsonb_build_object('lease_id',lid,'user_id',uid);
end$function$
;
CREATE OR REPLACE FUNCTION public.jf_password_self_service()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select jioflow_private.session_allowed() and not exists(select 1 from public.jf_shops where owner_id=auth.uid()) and not exists(select 1 from public.jf_memberships where user_id=auth.uid() and role='owner' and status<>'removed') and
 not exists(select 1 from public.jf_memberships where user_id=auth.uid() and role='agent' and status<>'removed') and
 (jioflow_private.is_creator() or exists(select 1 from public.jf_shops where owner_id=auth.uid() and active) or exists(select 1 from public.jf_memberships where user_id=auth.uid() and role='admin' and status='active'));
$function$
;
CREATE OR REPLACE FUNCTION public.jf_can_reset_password()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select jioflow_private.session_allowed() and
 (not exists(select 1 from public.jf_shops where owner_id=auth.uid()) and not exists(select 1 from public.jf_memberships where user_id=auth.uid() and role='owner' and status<>'removed') or exists(select 1 from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) a where a->>'method'='recovery' and (a->>'timestamp')::numeric>=extract(epoch from now()-interval '1 hour'))) and
 (not exists(select 1 from public.jf_memberships where user_id=auth.uid() and role='agent' and status<>'removed') or exists(select 1 from public.jf_password_requests r join public.jf_shops s on s.id=r.shop_id where r.user_id=auth.uid() and r.status='approved' and r.expires_at>now() and s.active));
$function$
;
commit;
