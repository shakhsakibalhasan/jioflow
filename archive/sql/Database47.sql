-- Managed password entry uses the server Auth API; no plaintext password reaches SQL.
begin;
do $$begin if not exists(select 1 from public.jf_schema_versions where version='030_order_recipient_edit') then raise exception 'Apply migration 030 first.';end if;end$$;
create table if not exists jioflow_private.password_set_leases(id uuid primary key default gen_random_uuid(),actor_id uuid not null references public.jf_profiles(id),user_id uuid not null references public.jf_profiles(id),request_id uuid references public.jf_password_requests(id),expires_at timestamptz not null default now()+interval '2 minutes',finished_at timestamptz,cancelled_at timestamptz);
alter table jioflow_private.password_set_leases enable row level security;
revoke all on jioflow_private.password_set_leases from public,anon,authenticated;
create or replace function public.jf_prepare_password_set(target_user uuid default null,reset_request uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=target_user;p public.jf_profiles%rowtype;r public.jf_password_requests%rowtype;m public.jf_memberships%rowtype;lid uuid;
begin
 if not jioflow_private.session_allowed() then raise exception 'Sign in again.' using errcode='42501';end if;
 if reset_request is not null then
  select * into r from public.jf_password_requests where id=reset_request for update;
  if not found or r.status not in('pending','approved') or (r.status='approved' and r.expires_at<=now()) or (uid is not null and uid<>r.user_id) then raise exception 'This reset request is closed.' using errcode='42501';end if;uid:=r.user_id;
 end if;
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
end$$;
create or replace function public.jf_finish_password_set(lease_id uuid,succeeded boolean) returns boolean language plpgsql security definer set search_path='' as $$
declare l jioflow_private.password_set_leases%rowtype;
begin
 select * into l from jioflow_private.password_set_leases where id=lease_id for update;
 if not found or l.finished_at is not null or l.cancelled_at is not null then raise exception 'Reset operation is closed.';end if;
 if not succeeded then
  update jioflow_private.password_set_leases set cancelled_at=now() where id=l.id;
  update public.jf_password_requests set status='pending',expires_at=null where id=l.request_id and status='approved';return true;
 end if;
 update jioflow_private.password_set_leases set finished_at=now() where id=l.id;
 update public.jf_password_requests set status='used',expires_at=now() where id=l.request_id and status in('approved','pending');
 insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by) select id,l.user_id,l.actor_id from auth.sessions where user_id=l.user_id on conflict do nothing;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(l.actor_id,l.user_id,'password_set',jsonb_build_object('request_id',l.request_id));
 insert into public.jf_notifications(recipient_id,kind,title,body,reference_id) values(l.user_id,'password_decision','Password updated','Your administrator updated your password. Sign in using the new password.',l.request_id);
 return true;
end$$;
revoke all on function public.jf_prepare_password_set(uuid,uuid),public.jf_finish_password_set(uuid,boolean) from public,anon,authenticated;
grant execute on function public.jf_prepare_password_set(uuid,uuid) to authenticated;
grant execute on function public.jf_finish_password_set(uuid,boolean) to service_role;
insert into public.jf_schema_versions(version) values('031_managed_password_reset') on conflict do nothing;
commit;


begin;
do $$begin if not exists(select 1 from public.jf_schema_versions where version='031_managed_password_reset') then raise exception 'Apply migration 031 first.';end if;end$$;
create or replace function public.jf_agent_workspace_context(target_shop uuid,target_agent uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.jf_memberships%rowtype;p public.jf_profiles%rowtype;
begin
 select * into m from public.jf_memberships where id=target_agent and shop_id=target_shop and role='agent' and status='active';
 if not found or not jioflow_private.session_allowed() then raise exception 'Agent workspace access denied.' using errcode='42501';end if;
 if not(jioflow_private.is_creator() or jioflow_private.can_manage_lower(m.user_id,'users')) then raise exception 'Agent workspace access denied.' using errcode='42501';end if;
 select * into p from public.jf_profiles where id=m.user_id and active and deleted_at is null;
 if not found then raise exception 'Agent is inactive.' using errcode='42501';end if;
 return jsonb_build_object('member',to_jsonb(m),'profile',to_jsonb(p),'can_edit_layout',jioflow_private.has_permission(target_shop,'settings'));
end$$;
create or replace function public.jf_agent_workspace_summary(target_shop uuid,target_agent uuid,report_start timestamptz default null,report_end timestamptz default null) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform public.jf_agent_workspace_context(target_shop,target_agent);
with c as(select c.*,f.status followup_status,f.call_outcome,f.callback_at from public.jf_customers c left join public.jf_followups f on f.shop_id=c.shop_id and f.customer_id=c.id where c.shop_id=target_shop and c.assigned_membership_id=target_agent and c.archived_at is null),o as(select * from public.jf_orders where shop_id=target_shop and assigned_membership_id=target_agent and archived_at is null and (report_start is null or created_at>=report_start) and (report_end is null or created_at<report_end))
 select jsonb_build_object('customers',(select count(*) from c),'unassigned',(select count(*) from c where assigned_membership_id is null),'assigned',(select count(*) from c where assigned_membership_id is not null),'completed',(select count(*) from c where followup_status='completed'),'pending',(select count(*) from c where coalesce(followup_status,'pending') in ('pending','callback')),'cancelled_customers',(select count(*) from c where followup_status='cancelled'),'permanent',(select count(*) from c where permanent),'connected',(select count(*) from c where call_outcome in ('connected','positive','negative','intermediate')),'not_connected',(select count(*) from c where call_outcome in ('not_connected','no_answer','busy')),'not_attempted',(select count(*) from c where call_outcome is null or call_outcome='not_attempted'),'positive',(select count(*) from c where call_outcome='positive'),'negative',(select count(*) from c where call_outcome='negative'),'intermediate',(select count(*) from c where call_outcome='intermediate'),'callbacks',(select count(*) from c where followup_status='callback' and callback_at<=now()),'orders',(select count(*) from o),'confirmed',(select count(*) from o where status not in ('draft','cancelled')),'draft',(select count(*) from o where status='draft'),'ready_to_book',(select count(*) from o where status in ('confirmed','ready_to_book')),'booked',(select count(*) from o where status='booked'),'in_transit',(select count(*) from o where status='in_transit'),'delivered',(select count(*) from o where status='delivered'),'returned',(select count(*) from o where status='returned'),'partial_delivery',(select count(*) from o where status='partial_delivery'),'cancelled',(select count(*) from o where status='cancelled'),'revenue',(select coalesce(sum(total),0) from o where status not in ('draft','cancelled')),'source_breakdown',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from(select case when lower(source) in('website','facebook','whatsapp') then lower(source) else 'other' end source,count(*) count from o where status not in('draft','cancelled') group by 1)t),'timeline',(select coalesce(jsonb_agg(to_jsonb(t) order by at,source),'[]') from(select date_trunc(case when report_end-report_start<=interval '1 day' then 'hour' else 'day' end,created_at at time zone 'Asia/Dhaka') at,case when lower(source) in('website','facebook','whatsapp') then lower(source) else 'other' end source,count(*) count from o where status not in('draft','cancelled') and created_at>=coalesce(report_end,now())-interval '30 days' group by 1,2)t),'purchase_rate',(select case when count(*) filter(where followup_status='completed')=0 then 0 else 100.0*count(*) filter(where followup_status='completed' and exists(select 1 from o where o.customer_id=c.id and o.status not in ('draft','cancelled')))/count(*) filter(where followup_status='completed') end from c)) into result;
 return result;
end$$;
revoke all on function public.jf_agent_workspace_context(uuid,uuid),public.jf_agent_workspace_summary(uuid,uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.jf_agent_workspace_context(uuid,uuid),public.jf_agent_workspace_summary(uuid,uuid,timestamptz,timestamptz) to authenticated;
create index if not exists jf_workspace_preferences_page_latest on public.jf_workspace_preferences(shop_id,page,updated_at desc);
create or replace function public.jf_workspace_tools(target_shop uuid,tool text,details jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;rid uuid;mid uuid;ids uuid[];agents uuid[];gid uuid;cid uuid;idx integer:=0;n integer;value jsonb;k text;old public.jf_order_finance%rowtype;
begin
 if not jioflow_private.reads_operations(target_shop) then raise exception 'Workspace access required.' using errcode='42501';end if;
 if jsonb_typeof(details)<>'object' then raise exception 'Invalid details.';end if;
 if tool='customer_orders' then
  cid:=(details->>'customer_id')::uuid;
  if not jioflow_private.can_read_customer(target_shop,cid) or not exists(select 1 from public.jf_customers where shop_id=target_shop and id=cid and archived_at is null) then raise exception 'Customer access denied.' using errcode='42501';end if;
  n:=coalesce((details->>'offset')::integer,0);if n<0 then raise exception 'Invalid offset.';end if;
  return coalesce((select jsonb_agg(to_jsonb(t)) from(select id,order_number,status,total,created_at from public.jf_orders where shop_id=target_shop and customer_id=cid and archived_at is null order by created_at desc,id limit 50 offset n)t),'[]');
 elsif tool='load' then
  return jsonb_build_object('settings',coalesce((select s.value from public.jf_workspace_settings s where s.shop_id=target_shop),'{}'),'layout',coalesce((select p.value from public.jf_workspace_preferences p where p.shop_id=target_shop and p.page=details->>'page' order by p.updated_at desc,p.user_id limit 1),(select p.value from public.jf_workspace_preferences p where p.shop_id=target_shop and p.page=regexp_replace(details->>'page','^a:[0-9a-f-]{36}:','') order by p.updated_at desc,p.user_id limit 1),'{}'),'groups',coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'name',g.name,'active',g.active,'members',coalesce((select jsonb_agg(m.membership_id) from public.jf_group_members m where m.shop_id=g.shop_id and m.group_id=g.id),'[]'))) from public.jf_groups g where g.shop_id=target_shop),'[]'));
 elsif tool='save_layout' then
  if not jioflow_private.has_permission(target_shop,'settings') or jioflow_private.agent_member(target_shop) is not null then raise exception 'Layout editing is not permitted.' using errcode='42501';end if;
  if length(coalesce(details->>'page','')) not between 1 and 50 or jsonb_typeof(details->'value') is distinct from 'object' or octet_length((details->'value')::text)>100000 then raise exception 'Invalid layout.';end if;
  insert into public.jf_workspace_preferences(shop_id,user_id,page,value) values(target_shop,auth.uid(),details->>'page',details->'value') on conflict(shop_id,user_id,page) do update set value=excluded.value,updated_at=now();
 elsif tool='save_settings' then
  if not jioflow_private.has_permission(target_shop,'settings') or jioflow_private.agent_member(target_shop) is not null then raise exception 'Settings editing is not permitted.' using errcode='42501';end if;
  value:=details->'value';if jsonb_typeof(value) is distinct from 'object' or octet_length(value::text)>100000 then raise exception 'Invalid settings.';end if;
  for k in select jsonb_object_keys(value) loop if k not in ('inside','outside','currency','statuses','tags','sources','pull_count','pull_sources','return_policy','schedule','hero') then raise exception 'Unsupported setting: %',k;end if;end loop;
  if value?'inside' and ((value->>'inside')::numeric<0 or (value->>'inside')::numeric>999999) or value?'outside' and ((value->>'outside')::numeric<0 or (value->>'outside')::numeric>999999) then raise exception 'Invalid delivery charge.';end if;
  if value?'pull_count' and (value->>'pull_count')::integer not between 1 and 1000 then raise exception 'Set pull count between 1 and 1000 per transaction.';end if;
  foreach k in array array['statuses','tags','sources','pull_sources'] loop if value?k and (jsonb_typeof(value->k)<>'array' or exists(select 1 from jsonb_array_elements(value->k) x where jsonb_typeof(x)<>'string' or length(x#>>'{}') not between 1 and 120)) then raise exception 'Invalid % list.',k;end if;end loop;
  insert into public.jf_workspace_settings(shop_id,value) values(target_shop,value) on conflict(shop_id) do update set value=public.jf_workspace_settings.value||excluded.value,updated_at=now();
 elsif tool in ('save_group','delete_group') then
  if not jioflow_private.manages_shop(target_shop) then raise exception 'User management permission required.' using errcode='42501';end if;
  gid:=nullif(details->>'id','')::uuid;
  if tool='delete_group' then
   delete from public.jf_group_members where shop_id=target_shop and group_id=gid;delete from public.jf_groups where shop_id=target_shop and id=gid;
  else
   if length(trim(coalesce(details->>'name',''))) not between 1 and 120 then raise exception 'Enter a group name.';end if;
   agents:=array(select x::uuid from jsonb_array_elements_text(coalesce(details->'members','[]')) x);
   if exists(select 1 from unnest(agents) a where not exists(select 1 from public.jf_memberships m join public.jf_profiles p on p.id=m.user_id where m.id=a and m.shop_id=target_shop and m.role='agent' and m.status<>'removed' and p.active)) then raise exception 'Choose Agents from this shop.';end if;
   if gid is null then insert into public.jf_groups(shop_id,name) values(target_shop,trim(details->>'name')) returning id into gid;
   else update public.jf_groups set name=trim(details->>'name') where shop_id=target_shop and id=gid;if not found then raise exception 'Group not found.';end if;end if;
   delete from public.jf_group_members where shop_id=target_shop and group_id=gid;
   insert into public.jf_group_members(shop_id,group_id,membership_id) select target_shop,gid,a from unnest(agents) a on conflict do nothing;
  end if;
 elsif tool='distribute' then
  if not jioflow_private.has_permission(target_shop,'assign') or jioflow_private.agent_member(target_shop) is not null then raise exception 'Distribution permission required.' using errcode='42501';end if;
  ids:=array(select x::uuid from jsonb_array_elements_text(coalesce(details->'ids','[]')) x);
  if cardinality(ids)=0 then raise exception 'Select customers first.';end if;
  gid:=nullif(details->>'group_id','')::uuid;mid:=nullif(details->>'membership_id','')::uuid;
  if gid is not null then agents:=array(select m.id from public.jf_group_members gm join public.jf_memberships m on m.id=gm.membership_id join public.jf_profiles p on p.id=m.user_id where gm.shop_id=target_shop and gm.group_id=gid and m.shop_id=target_shop and m.status='active' and m.role='agent' and p.active order by m.id);if cardinality(agents)=0 then raise exception 'This group has no active Agents.';end if;
  elsif mid is not null then
   if not exists(select 1 from public.jf_memberships m join public.jf_profiles p on p.id=m.user_id where m.id=mid and m.shop_id=target_shop and m.status='active' and m.role='agent' and p.active) then raise exception 'Choose an active Agent in this shop.';end if;agents:=array[mid];
  else agents:=array[]::uuid[];end if;
  perform 1 from public.jf_customers c where c.shop_id=target_shop and c.id=any(ids) order by c.id for update;
  if (select count(*) from public.jf_customers c where c.shop_id=target_shop and c.archived_at is null and c.id=any(ids))<>(select count(distinct a) from unnest(ids) a) then raise exception 'A selected customer is unavailable in this shop.';end if;
  for cid in select c.id from public.jf_customers c where c.shop_id=target_shop and c.id=any(ids) order by c.id loop
   mid:=case when cardinality(agents)>0 then agents[1+(idx%cardinality(agents))] end;
   update public.jf_customers set assigned_membership_id=mid,permanent=case when mid is null then false else permanent end,unassignment_tag=coalesce(details->>'tag',''),updated_at=now() where id=cid;idx:=idx+1;
  end loop;
 elsif tool='pull' then
  mid:=jioflow_private.agent_member(target_shop);
  if mid is null or not jioflow_private.has_permission(target_shop,'pull') then raise exception 'Take More Orders is not permitted.' using errcode='42501';end if;
  select s.value into value from public.jf_workspace_settings s where s.shop_id=target_shop;
  n:=coalesce((value->>'pull_count')::integer,20);if n not between 1 and 1000 then raise exception 'Ask Admin to configure pull count.';end if;
  with chosen as(select c.id from public.jf_customers c where c.shop_id=target_shop and c.archived_at is null and c.assigned_membership_id is null and (coalesce(jsonb_array_length(value->'pull_sources'),0)=0 or lower(c.source) in(select lower(jsonb_array_elements_text(value->'pull_sources')))) order by c.updated_at,c.id for update skip locked limit n),updated as(update public.jf_customers c set assigned_membership_id=mid,updated_at=now() from chosen where c.id=chosen.id returning c.id) select count(*) into idx from updated;
 elsif tool='products' then
  if not jioflow_private.has_permission(target_shop,'products') then raise exception 'Product editing is not permitted.' using errcode='42501';end if;
  ids:=array(select x::uuid from jsonb_array_elements_text(coalesce(details->'ids','[]')) x);if cardinality(ids)=0 then raise exception 'Select products first.';end if;
  if details->>'action' not in ('activate','deactivate','archive','restore','feature','unfeature') then raise exception 'Invalid product action.';end if;
  update public.jf_products set featured=case when details->>'action'='feature' then true when details->>'action'='unfeature' then false else featured end,active=case when details->>'action'='activate' then true when details->>'action'='deactivate' then false else active end,archived_at=case when details->>'action'='archive' then now() when details->>'action'='restore' then null else archived_at end,updated_at=now() where shop_id=target_shop and id=any(ids);get diagnostics idx=row_count;
 elsif tool='customer_labels' then
  cid:=(details->>'customer_id')::uuid;
  if not jioflow_private.has_permission(target_shop,'assign') or not jioflow_private.can_read_customer(target_shop,cid) then raise exception 'Customer editing is not permitted.' using errcode='42501';end if;
  if length(coalesce(details->>'label',''))>120 or length(coalesce(details->>'tag',''))>120 then raise exception 'Label or tag too long.';end if;
  update public.jf_customers set workflow_label=coalesce(details->>'label',''),unassignment_tag=coalesce(details->>'tag',''),updated_at=now() where shop_id=target_shop and id=cid and archived_at is null;
 elsif tool='save_finance' then
  if not jioflow_private.has_permission(target_shop,'profit') then raise exception 'Finance permission required.' using errcode='42501';end if;
  rid:=(details->>'order_id')::uuid;
  perform 1 from public.jf_orders where id=rid and shop_id=target_shop and archived_at is null for update;if not found then raise exception 'Order not found.';end if;
  select * into old from public.jf_order_finance where shop_id=target_shop and order_id=rid;
  foreach k in array array['product_cost','courier_charge','cod_fee','packaging_cost','return_cost','other_cost','cod_expected','cod_received'] loop if not details?k or (details->>k)::numeric<0 or (details->>k)::numeric>999999999999.99 then raise exception 'Check %.',k;end if;end loop;
  insert into public.jf_order_finance(shop_id,order_id,product_cost,courier_charge,cod_fee,packaging_cost,return_cost,other_cost,cod_expected,cod_received) values(target_shop,rid,(details->>'product_cost')::numeric,(details->>'courier_charge')::numeric,(details->>'cod_fee')::numeric,(details->>'packaging_cost')::numeric,(details->>'return_cost')::numeric,(details->>'other_cost')::numeric,(details->>'cod_expected')::numeric,(details->>'cod_received')::numeric)
  on conflict(order_id) do update set product_cost=excluded.product_cost,courier_charge=excluded.courier_charge,cod_fee=excluded.cod_fee,packaging_cost=excluded.packaging_cost,return_cost=excluded.return_cost,other_cost=excluded.other_cost,cod_expected=excluded.cod_expected,cod_received=excluded.cod_received,updated_at=now();
 else raise exception 'Unknown workspace tool.';end if;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),auth.uid(),'workspace_'||tool,jsonb_build_object('shop_id',target_shop,'count',idx,'record_id',coalesce(rid,gid,cid)));
 return jsonb_build_object('saved',true,'id',coalesce(rid,gid,cid),'count',idx);
end $$;
insert into public.jf_schema_versions(version) values('032_agent_workspace') on conflict do nothing;
commit;
