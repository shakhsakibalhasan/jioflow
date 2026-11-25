-- Apply after Database166. Preserves session revocation and shop boundaries.
begin;
CREATE OR REPLACE FUNCTION public.jf_manage_account(target_user uuid, account_action text, details jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.jf_memberships%rowtype;
begin
 if jioflow_private.is_creator() then return public.jf_manage_account_creator(target_user,account_action,details);end if;
 if not (jioflow_private.can_manage_lower(target_user,case when account_action='force_logout' then 'logout' else 'users' end) or (account_action in('activate','deactivate','remove') and (jioflow_private.session_allowed() and target_user<>auth.uid() and exists(select 1 from public.jf_memberships t join public.jf_profiles p on p.id=t.user_id join public.jf_memberships a on a.shop_id=t.shop_id join public.jf_shops s on s.id=t.shop_id where t.user_id=target_user and t.role='agent' and t.status<>'removed' and p.platform_role is distinct from 'creator' and p.deleted_at is null and a.user_id=auth.uid() and a.role='admin' and a.status='active' and s.active and not exists(select 1 from public.jf_shops own where own.owner_id=target_user))))) then raise exception 'This account cannot be managed.' using errcode='42501';end if;
 if account_action not in ('activate','deactivate','force_logout','remove') then raise exception 'Unsupported action.';end if;
 select * into m from public.jf_memberships where user_id=target_user and status<>'removed' for update;
 if account_action in ('deactivate','remove','force_logout') then
  insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by) select id,target_user,auth.uid() from auth.sessions where user_id=target_user on conflict do nothing;
  update public.jf_agent_sessions set status='revoked' where user_id=target_user and status in ('pending','approved');
 end if;
 if account_action in ('activate','deactivate') then update public.jf_profiles set active=account_action='activate' where id=target_user;end if;
 if account_action='remove' then
  update public.jf_customers set assigned_membership_id=null,permanent=false where shop_id=m.shop_id and assigned_membership_id=m.id;
  delete from public.jf_group_members where shop_id=m.shop_id and membership_id=m.id;
  update public.jf_memberships set status='removed' where id=m.id;update public.jf_profiles set active=false,deleted_at=now() where id=target_user;
 end if;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),target_user,'delegated_'||account_action,jsonb_build_object('shop_id',m.shop_id));
 return jsonb_build_object('message','Account updated.');
end $function$
;
CREATE OR REPLACE FUNCTION public.jf_workspace_tools(target_shop uuid, tool text, details jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  if not jioflow_private.has_permission(target_shop,'settings') then raise exception 'Layout editing is not permitted.' using errcode='42501';end if;
  if length(coalesce(details->>'page','')) not between 1 and 50 or jsonb_typeof(details->'value') is distinct from 'object' or octet_length((details->'value')::text)>100000 then raise exception 'Invalid layout.';end if;
  insert into public.jf_workspace_preferences(shop_id,user_id,page,value) values(target_shop,auth.uid(),details->>'page',details->'value') on conflict(shop_id,user_id,page) do update set value=excluded.value,updated_at=now();
 elsif tool='save_settings' then
  if not jioflow_private.has_permission(target_shop,'settings') then raise exception 'Settings editing is not permitted.' using errcode='42501';end if;
  value:=details->'value';if jsonb_typeof(value) is distinct from 'object' or octet_length(value::text)>100000 then raise exception 'Invalid settings.';end if;
  for k in select jsonb_object_keys(value) loop if k not in ('inside','outside','currency','statuses','tags','sources','pull_count','pull_sources','return_policy','schedule','hero') then raise exception 'Unsupported setting: %',k;end if;end loop;
  if value?'inside' and ((value->>'inside')::numeric<0 or (value->>'inside')::numeric>999999) or value?'outside' and ((value->>'outside')::numeric<0 or (value->>'outside')::numeric>999999) then raise exception 'Invalid delivery charge.';end if;
  if value?'pull_count' and (value->>'pull_count')::integer not between 1 and 1000 then raise exception 'Set pull count between 1 and 1000 per transaction.';end if;
  foreach k in array array['statuses','tags','sources','pull_sources'] loop if value?k and (jsonb_typeof(value->k)<>'array' or exists(select 1 from jsonb_array_elements(value->k) x where jsonb_typeof(x)<>'string' or length(x#>>'{}') not between 1 and 120)) then raise exception 'Invalid % list.',k;end if;end loop;
  insert into public.jf_workspace_settings(shop_id,value) values(target_shop,value) on conflict(shop_id) do update set value=public.jf_workspace_settings.value||excluded.value,updated_at=now();
 elsif tool in ('save_group','delete_group') then
  if not (jioflow_private.manages_shop(target_shop) or (jioflow_private.session_allowed() and exists(select 1 from public.jf_memberships a where a.shop_id=target_shop and a.user_id=auth.uid() and a.role='admin' and a.status='active'))) then raise exception 'User management permission required.' using errcode='42501';end if;
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
end $function$
;
CREATE OR REPLACE FUNCTION public.jf_panel_heartbeat(device_id text, target_shop uuid DEFAULT NULL::uuid, include_inbox boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare allowed boolean;gate jsonb;workspace jsonb;feed jsonb;resets jsonb;logins jsonb;creator boolean;
begin
 allowed:=public.jf_session_status();
 if not coalesce(allowed,false) then return jsonb_build_object('allowed',false);end if;
 workspace:=public.jf_workspace_status();
 gate:=public.jf_agent_session(device_id); perform public.jf_presence135();
 if include_inbox then
  feed:=public.jf_notifications_feed(target_shop);
  begin resets:=public.jf_password_requests_feed();exception when insufficient_privilege then resets:='[]'::jsonb;end;
  select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into logins from(select * from public.jf_agent_sessions where status='pending' order by requested_at desc limit 100)t;
 end if;
 return jsonb_build_object('change_stamp152',case when coalesce((gate->>'is_agent')::boolean,false) and gate->>'status'<>'approved' then null else public.jf_change_stamp152(target_shop) end,'allowed',true,'gate',gate,'workspace',workspace,'feed',feed,'resets',resets,'logins',logins);
end$function$
;

create or replace function public.jf_agent_devices167(target_user uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare m public.jf_memberships%rowtype;result jsonb;begin
 select * into m from public.jf_memberships where user_id=target_user and role='agent' and status<>'removed';
 if not found or not jioflow_private.session_allowed() or not (
 target_user=auth.uid() or jioflow_private.is_creator() or jioflow_private.owns_shop(m.shop_id) or exists(select 1 from public.jf_memberships a where a.shop_id=m.shop_id and a.user_id=auth.uid() and a.role='admin' and a.status='active') or jioflow_private.manages_shop(m.shop_id)) then
 raise exception 'Agent device access denied.' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(t)),'[]') into result from (
 select a.status,a.requested_at,a.decided_at,a.device_details141 as device,
 exists(select 1 from auth.sessions s where s.id=a.session_id and s.user_id=a.user_id) as session_valid,
 case when a.status='approved' then p.last_seen end as last_seen,
 (a.status='approved' and p.last_seen>now()-interval '90 seconds' and exists(select 1 from auth.sessions s where s.id=a.session_id and s.user_id=a.user_id) and not exists(select 1 from jioflow_private.revoked_sessions r where r.session_id=a.session_id) and exists(select 1 from public.jf_profiles u where u.id=a.user_id and u.active and u.deleted_at is null)) as online
 from public.jf_agent_sessions a left join jioflow_private.agent_presence135 p on p.shop_id=a.shop_id and p.user_id=a.user_id
 where a.shop_id=m.shop_id and a.user_id=target_user order by a.requested_at desc limit 20)t;
 return result;
end $$;
revoke all on function public.jf_agent_devices167(uuid) from public,anon;
grant execute on function public.jf_agent_devices167(uuid) to authenticated;
CREATE OR REPLACE FUNCTION jioflow_private.jf_latest_orders167(target_shop uuid, target_agent uuid, target_ids uuid[])
 RETURNS TABLE(customer_id uuid, order_date date, data jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
 SET plan_cache_mode TO 'force_custom_plan'
AS $function$
declare staff112 boolean;agent112 uuid;
begin
 staff112:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);agent112:=jioflow_private.agent_member(target_shop);
 if not staff112 and agent112 is null then raise exception 'Workspace access required.' using errcode='42501';end if;
 return query with chosen as materialized (
 select distinct on(m.cid) m.* from (
 select h.customer_id cid,h.order_date d,h.updated_at t,h.history_id id,true imported
 from jioflow_private.jf_latest_history117 h join public.jf_customers c on c.shop_id=h.shop_id and c.id=h.customer_id where h.shop_id=target_shop and c.id=any(target_ids) and c.archived_at is null and (target_agent is null or c.assigned_membership_id=target_agent) and (staff112 or c.assigned_membership_id=agent112)
 union all select z.customer_id,(z.created_at at time zone 'Asia/Dhaka')::date,z.created_at,z.id,false
 from public.jf_orders z join public.jf_customers c on c.shop_id=z.shop_id and c.id=z.customer_id where z.shop_id=target_shop and z.archived_at is null and c.id=any(target_ids) and c.archived_at is null and (target_agent is null or c.assigned_membership_id=target_agent) and (staff112 or c.assigned_membership_id=agent112) and (staff112 or z.assigned_membership_id=agent112 or z.entered_by=auth.uid())
 ) m order by m.cid,m.d desc nulls last,m.t desc,m.id desc
 ) select k.cid,k.d,case when k.imported then
 h.payload else jsonb_build_object('total',z.total,'advance',(select coalesce(sum(p.amount),0) from public.jf_payments p where p.shop_id=z.shop_id and p.order_id=z.id and p.status in('pending','verified')),'status',z.status,'source',z.source,'sku',(select string_agg(p.sku,' ') from public.jf_order_items i join public.jf_products p on p.shop_id=i.shop_id and p.id=i.product_id where i.shop_id=z.shop_id and i.order_id=z.id),'imported',false) end
 from chosen k left join jioflow_private.jf_history_summary117 h on k.imported and h.shop_id=target_shop and h.history_id=k.id left join public.jf_orders z on not k.imported and z.shop_id=target_shop and z.id=k.id;
end $function$
;

revoke all on function jioflow_private.jf_latest_orders167(uuid,uuid,uuid[]) from public,anon,authenticated;

do $patch$ declare d text;begin
 select pg_get_functiondef('jioflow_private.jf_workspace_page_staff73(uuid,text,jsonb,integer)'::regprocedure) into d;
 if position('native_dates as materialized' in d)=0 then
 d:=replace(d,$old$ if entity='customers' then$old$,$new$
 if entity='customers' and coalesce(filters->>'_fast','')='true' and st='all'
 and not exists(select 1 from jsonb_each_text(filters) x where x.key not in('status','search','_fast','_date_desc132','_page_size','_exclude_permanent134','agent_id') and coalesce(x.value,'')<>'') and search='' then
 with native_dates as materialized(select z.customer_id,max((z.created_at at time zone 'Asia/Dhaka')::date) d from public.jf_orders z where z.shop_id=target_shop and z.archived_at is null group by z.customer_id),
 dates as(select c.id,greatest(h.order_date,n.d) d from public.jf_customers c left join jioflow_private.jf_latest_history117 h on h.shop_id=c.shop_id and h.customer_id=c.id left join native_dates n on n.customer_id=c.id
 where c.shop_id=target_shop and c.archived_at is null and (agent_id is null or c.assigned_membership_id=agent_id) and (coalesce(filters->>'_exclude_permanent134','false')<>'true' or not c.permanent)),
 page as materialized(select * from dates order by case when coalesce(filters->>'_date_desc132','false')='true' then d end desc nulls last,case when coalesce(filters->>'_date_desc132','false')<>'true' then d end asc nulls last,id limit public.jf_page_size75(filters) offset page_number::bigint*public.jf_page_size75(filters)),
 meta as materialized(select * from jioflow_private.jf_latest_orders167(target_shop,agent_id,array(select id from page)))
 select jsonb_build_object('total',(select count(*) from dates),'counts',null,'rows',coalesce((select jsonb_agg(to_jsonb(t)) from(
 select c.*,f.status followup_status,f.call_outcome,f.callback_at,false has_confirmed,m.data->>'status' latest_order_status,m.data->>'sku' latest_sku,m.order_date,public.jf_order_amount_value(m.data->>'total') order_amount,(select jsonb_build_object('status',ih.payload->>'status') from jioflow_private.jf_latest_history117 ih where ih.shop_id=c.shop_id and ih.customer_id=c.id) imported_history144,case when f.id is not null then jsonb_build_object('customer',f.customer_status130,'call',f.call_status130) end agent_outcome144
 from page p join public.jf_customers c on c.shop_id=target_shop and c.id=p.id left join public.jf_followups f on f.shop_id=c.shop_id and f.customer_id=c.id left join meta m on m.customer_id=c.id
 order by case when coalesce(filters->>'_date_desc132','false')='true' then p.d end desc nulls last,case when coalesce(filters->>'_date_desc132','false')<>'true' then p.d end asc nulls last,c.id)t),'[]'::jsonb)) into result;
 return result;
 end if;
 if entity='customers' then$new$);execute d;end if;
end $patch$;
CREATE OR REPLACE FUNCTION public.jf_order_finance167(target_shop uuid, report_start timestamptz default null, report_end timestamptz default null)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
 if not jioflow_private.has_permission(target_shop,'profit') then raise exception 'Finance access denied.' using errcode='42501';end if;
 with item_costs as materialized(
 select i.order_id,coalesce(sum(i.quantity*pc.unit_cost) filter(where pc.unit_cost is not null),0) known_cost,
 coalesce(sum(i.quantity*i.unit_price) filter(where pc.unit_cost is not null),0) known_sales,
 coalesce(sum(i.quantity*i.unit_price),0) all_sales,
 count(*) filter(where pc.unit_cost is null) missing
 from public.jf_order_items i left join public.jf_product_costs pc on pc.shop_id=i.shop_id and pc.product_id=i.product_id
 where i.shop_id=target_shop group by i.order_id
 ),o as(select o.*,coalesce(f.product_cost,ic.known_cost,0) product_cost,
 case when f.product_cost is not null then 1::numeric when ic.all_sales>0 then least(1::numeric,greatest(0::numeric,ic.known_sales/ic.all_sales)) else 0::numeric end known_ratio,
 (f.product_cost is null and coalesce(ic.missing,1)>0) missing_cost,
 coalesce(f.courier_charge,o.delivery_charge)+coalesce(f.cod_fee,0)+coalesce(f.packaging_cost,0)+coalesce(f.return_cost,0)+coalesce(f.other_cost,0) fees,
 case when o.status='delivered' then greatest(0,coalesce(f.cod_expected,(select (s.request_payload->>'cod_amount')::numeric from public.jf_shipments s where s.shop_id=o.shop_id and s.order_id=o.id and s.courier='steadfast' and s.consignment_id is not null order by s.created_at desc limit 1),o.total-coalesce((select sum(amount) from public.jf_payments p where p.shop_id=target_shop and p.order_id=o.id and p.status='verified'),0))-coalesce(f.cod_received,0)) else 0 end cod_pending
 from public.jf_orders o left join item_costs ic on ic.order_id=o.id left join public.jf_order_finance f on f.shop_id=o.shop_id and f.order_id=o.id where o.shop_id=target_shop and (report_start is null or o.created_at>=report_start) and (report_end is null or o.created_at<report_end) and o.archived_at is null and o.status not in('draft','cancelled'))
 select jsonb_build_object('revenue',coalesce(sum(total),0),'product_cost',coalesce(sum(product_cost),0),'fees',coalesce(sum(fees),0),'profit',coalesce(sum((total-fees)*known_ratio-product_cost),0),'cod_pending',coalesce(sum(cod_pending),0),'missing_cost_orders',count(*) filter(where missing_cost),'agents',(select coalesce(jsonb_object_agg(t.member,t.profit),'{}') from(select coalesce(assigned_membership_id::text,'unassigned') member,sum((total-fees)*known_ratio-product_cost) profit from o group by assigned_membership_id)t)) into result from o;
 return result;
end $function$
;

revoke all on function public.jf_order_finance167(uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.jf_order_finance167(uuid,timestamptz,timestamptz) to authenticated;
commit;
