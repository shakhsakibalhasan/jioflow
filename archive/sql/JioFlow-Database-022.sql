-- Apply ONCE after migration 013. All updates run atomically.
begin;
-- 014_workspace_tools.sql
-- Apply after 013. Durable workspace controls and server-checked operations.
do $$ begin if not exists(select 1 from public.jf_schema_versions where version='013_product_images') then raise exception 'Apply migration 013 first.';end if;end $$;
create table public.jf_workspace_preferences(
 shop_id uuid not null references public.jf_shops(id) on delete cascade,
 user_id uuid not null references public.jf_profiles(id) on delete cascade,
 page text not null check(length(page) between 1 and 50),
 value jsonb not null default '{}' check(jsonb_typeof(value)='object'),updated_at timestamptz not null default now(),primary key(shop_id,user_id,page)
);
create table public.jf_workspace_settings(
 shop_id uuid primary key references public.jf_shops(id) on delete cascade,
 value jsonb not null default '{}' check(jsonb_typeof(value)='object'),updated_at timestamptz not null default now()
);
alter table public.jf_workspace_preferences enable row level security;
alter table public.jf_workspace_settings enable row level security;
revoke all on public.jf_workspace_preferences,public.jf_workspace_settings from anon,authenticated;
-- Custom labels are supplementary to stable pending/callback/completed/cancelled states.
alter table public.jf_customers add column workflow_label text not null default '',add column unassignment_tag text not null default '';
alter table public.jf_products add column featured boolean not null default false;
create function public.jf_workspace_tools(target_shop uuid,tool text,details jsonb default '{}') returns jsonb
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
  return jsonb_build_object('settings',coalesce((select s.value from public.jf_workspace_settings s where s.shop_id=target_shop),'{}'),'layout',coalesce((select p.value from public.jf_workspace_preferences p where p.shop_id=target_shop and p.user_id=auth.uid() and p.page=details->>'page'),'{}'),'groups',coalesce((select jsonb_agg(jsonb_build_object('id',g.id,'name',g.name,'active',g.active,'members',coalesce((select jsonb_agg(m.membership_id) from public.jf_group_members m where m.shop_id=g.shop_id and m.group_id=g.id),'[]'))) from public.jf_groups g where g.shop_id=target_shop),'[]'));
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
revoke all on function public.jf_workspace_tools(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.jf_workspace_tools(uuid,text,jsonb) to authenticated;
insert into public.jf_schema_versions(version) values('014_workspace_tools');


-- 015_reporting_pages.sql
-- Full-database counts and filtered pagination run as the signed-in user: existing RLS applies.
create function public.jf_workspace_summary(target_shop uuid,report_start timestamptz default null,report_end timestamptz default null) returns jsonb
language sql stable security invoker set search_path='' as $$
 with c as(select c.*,f.status followup_status,f.call_outcome,f.callback_at from public.jf_customers c left join public.jf_followups f on f.shop_id=c.shop_id and f.customer_id=c.id where c.shop_id=target_shop and c.archived_at is null),o as(select * from public.jf_orders where shop_id=target_shop and archived_at is null and (report_start is null or created_at>=report_start) and (report_end is null or created_at<report_end))
 select jsonb_build_object('customers',(select count(*) from c),'unassigned',(select count(*) from c where assigned_membership_id is null),'assigned',(select count(*) from c where assigned_membership_id is not null),'completed',(select count(*) from c where followup_status='completed'),'pending',(select count(*) from c where coalesce(followup_status,'pending') in ('pending','callback')),'cancelled_customers',(select count(*) from c where followup_status='cancelled'),'permanent',(select count(*) from c where permanent),'connected',(select count(*) from c where call_outcome in ('connected','positive','negative','intermediate')),'not_connected',(select count(*) from c where call_outcome in ('not_connected','no_answer','busy')),'not_attempted',(select count(*) from c where call_outcome is null or call_outcome='not_attempted'),'positive',(select count(*) from c where call_outcome='positive'),'negative',(select count(*) from c where call_outcome='negative'),'intermediate',(select count(*) from c where call_outcome='intermediate'),'callbacks',(select count(*) from c where followup_status='callback' and callback_at<=now()),'orders',(select count(*) from o),'confirmed',(select count(*) from o where status not in ('draft','cancelled')),'draft',(select count(*) from o where status='draft'),'ready_to_book',(select count(*) from o where status in ('confirmed','ready_to_book')),'booked',(select count(*) from o where status='booked'),'in_transit',(select count(*) from o where status='in_transit'),'delivered',(select count(*) from o where status='delivered'),'returned',(select count(*) from o where status='returned'),'partial_delivery',(select count(*) from o where status='partial_delivery'),'cancelled',(select count(*) from o where status='cancelled'),'revenue',(select coalesce(sum(total),0) from o where status not in ('draft','cancelled')),'source_breakdown',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from(select case when lower(source) in('website','facebook','whatsapp') then lower(source) else 'other' end source,count(*) count from o where status not in('draft','cancelled') group by 1)t),'timeline',(select coalesce(jsonb_agg(to_jsonb(t) order by at,source),'[]') from(select date_trunc(case when report_end-report_start<=interval '1 day' then 'hour' else 'day' end,created_at at time zone 'Asia/Dhaka') at,case when lower(source) in('website','facebook','whatsapp') then lower(source) else 'other' end source,count(*) count from o where status not in('draft','cancelled') and created_at>=coalesce(report_end,now())-interval '30 days' group by 1,2)t),'purchase_rate',(select case when count(*) filter(where followup_status='completed')=0 then 0 else 100.0*count(*) filter(where followup_status='completed' and exists(select 1 from o where o.customer_id=c.id and o.status not in ('draft','cancelled')))/count(*) filter(where followup_status='completed') end from c));
$$;
create function public.jf_workspace_page(target_shop uuid,entity text,filters jsonb default '{}',page_number integer default 0) returns jsonb
language plpgsql stable security invoker set search_path='' as $$
declare result jsonb;st text:=coalesce(filters->>'status','all');search text:=trim(coalesce(filters->>'search',''));agent_id uuid:=nullif(filters->>'agent_id','')::uuid;
begin
 if page_number is null or page_number<0 or length(search)>200 then raise exception 'Invalid page filter.';end if;
 if entity='customers' then
  with c as(select c.*,f.status followup_status,f.call_outcome,f.callback_at from public.jf_customers c left join public.jf_followups f on f.shop_id=c.shop_id and f.customer_id=c.id where c.shop_id=target_shop and c.archived_at is null and (agent_id is null or c.assigned_membership_id=agent_id)
   and (search='' or c.full_name ilike '%'||search||'%' or c.phone ilike '%'||search||'%')
   and (st='all' or st='unassigned' and c.assigned_membership_id is null or st='assigned' and c.assigned_membership_id is not null or st='permanent' and c.permanent or st='completed' and f.status='completed' or st='pending' and coalesce(f.status,'pending') in ('pending','callback') or st='cancelled' and f.status='cancelled' or st='connected' and f.call_outcome in ('connected','positive','negative','intermediate') or st='not_connected' and f.call_outcome in ('not_connected','no_answer','busy') or st='not_attempted' and (f.call_outcome is null or f.call_outcome='not_attempted') or st in ('positive','negative','intermediate') and f.call_outcome=st or st='callbacks' and f.status='callback' and f.callback_at<=now() or st='buyers' and f.status='completed' and exists(select 1 from public.jf_orders o where o.shop_id=target_shop and o.customer_id=c.id and o.archived_at is null and o.status not in ('draft','cancelled'))))
  select jsonb_build_object('total',(select count(*) from c),'rows',coalesce((select jsonb_agg(to_jsonb(p)) from(select * from c order by updated_at desc,id limit 50 offset page_number::bigint*50) p),'[]')) into result;
 elsif entity='orders' then
  with o as(select o.* from public.jf_orders o where o.shop_id=target_shop and o.archived_at is null and (agent_id is null or o.assigned_membership_id=agent_id)
   and (nullif(filters->>'report_start','') is null or o.created_at>=(filters->>'report_start')::timestamptz) and (nullif(filters->>'report_end','') is null or o.created_at<(filters->>'report_end')::timestamptz) and (coalesce(filters->>'source','')='' or case when lower(o.source) in('website','facebook','whatsapp') then lower(o.source) else 'other' end=filters->>'source') and (search='' or o.order_number ilike '%'||search||'%' or o.recipient_name ilike '%'||search||'%' or o.recipient_phone ilike '%'||search||'%')
   and(st='all' or st='confirmed' and o.status not in ('draft','cancelled') or st='ready_to_book' and o.status in ('confirmed','ready_to_book') or st not in ('confirmed','ready_to_book') and o.status=st))
  select jsonb_build_object('total',(select count(*) from o),'rows',coalesce((select jsonb_agg(to_jsonb(p)) from(select * from o order by created_at desc,id limit 50 offset page_number::bigint*50) p),'[]')) into result;
 else raise exception 'Choose customers or orders.';end if;
 return result;
end $$;
revoke all on function public.jf_workspace_summary(uuid,timestamptz,timestamptz),public.jf_workspace_page(uuid,text,jsonb,integer) from public,anon,authenticated;
grant execute on function public.jf_workspace_summary(uuid,timestamptz,timestamptz),public.jf_workspace_page(uuid,text,jsonb,integer) to authenticated;
insert into public.jf_schema_versions(version) values('015_reporting_pages');

-- 016_delegated_accounts.sql
-- Same-business delegation: Owner manages Admin/Agent; permitted Admin manages Agent only.
create function jioflow_private.can_manage_lower(target_user uuid,permission_name text default 'users') returns boolean
language sql stable security definer set search_path='' as $$
 select target_user<>auth.uid() and exists(select 1 from public.jf_profiles p join public.jf_memberships m on m.user_id=p.id where p.id=target_user and p.platform_role is distinct from 'creator' and p.deleted_at is null and m.status<>'removed' and not exists(select 1 from public.jf_shops s where s.owner_id=p.id) and jioflow_private.has_permission(m.shop_id,permission_name) and (jioflow_private.owns_shop(m.shop_id) and m.role in ('admin','agent') or m.role='agent' and exists(select 1 from public.jf_memberships a where a.shop_id=m.shop_id and a.user_id=auth.uid() and a.role='admin' and a.status='active')));
$$;
revoke all on function jioflow_private.can_manage_lower(uuid,text) from public,anon,authenticated;
alter function public.jf_save_profile(uuid,jsonb) rename to jf_save_profile_creator;
revoke all on function public.jf_save_profile_creator(uuid,jsonb) from public,anon,authenticated;
create function public.jf_save_profile(target_user uuid,details jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.jf_profiles%rowtype;m public.jf_memberships%rowtype;k text;v jsonb;avatar text;
begin
 if target_user=auth.uid() or jioflow_private.is_creator() then return public.jf_save_profile_creator(target_user,details);end if;
 if not jioflow_private.can_manage_lower(target_user) then raise exception 'This account is outside your management permissions.' using errcode='42501';end if;
 select * into p from public.jf_profiles where id=target_user for update;
 select * into m from public.jf_memberships where user_id=target_user and status<>'removed' for update;
 if jsonb_typeof(details)<>'object' or exists(select 1 from jsonb_object_keys(details) field(key) where field.key not in ('full_name','phone','job_title','address','user_code','avatar_path','permissions')) then raise exception 'Role and business changes require Creator access.' using errcode='42501';end if;
 if length(trim(coalesce(details->>'full_name',p.full_name))) not between 1 and 120 or length(coalesce(details->>'phone',p.phone))>30 or length(coalesce(details->>'address',p.address))>1000 or length(coalesce(details->>'job_title',p.job_title))>120 or length(coalesce(details->>'user_code',p.user_code))>40 then raise exception 'Check profile field lengths.';end if;
 avatar:=coalesce(details->>'avatar_path',p.avatar_path,'');if length(avatar)>350000 or (avatar<>'' and avatar !~ '^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$') then raise exception 'Upload a valid small profile image.';end if;
 if details?'permissions' then
  if jsonb_typeof(details->'permissions')<>'object' then raise exception 'Invalid permissions.';end if;
  for k,v in select * from jsonb_each(details->'permissions') loop
   if k not in ('users','assign','booking','products','import','export','profit','settings','approval','logout','integration','pull','price','discount','advance') or jsonb_typeof(v)<>'boolean' or (m.role='agent' and k in ('users','products','export','profit','settings','approval','logout','integration') and v='true'::jsonb) then raise exception 'Invalid permission.' using errcode='42501';end if;
  end loop;
  update public.jf_memberships set permissions=details->'permissions' where id=m.id;
 end if;
 update public.jf_profiles set full_name=trim(coalesce(details->>'full_name',full_name)),phone=trim(coalesce(details->>'phone',phone)),job_title=trim(coalesce(details->>'job_title',job_title)),address=coalesce(details->>'address',address),user_code=trim(coalesce(details->>'user_code',user_code)),avatar_path=nullif(avatar,'') where id=target_user;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),target_user,'delegated_profile_edit',jsonb_build_object('shop_id',m.shop_id));
 return jsonb_build_object('message','Profile saved.');
end $$;
alter function public.jf_manage_account(uuid,text,jsonb) rename to jf_manage_account_creator;
revoke all on function public.jf_manage_account_creator(uuid,text,jsonb) from public,anon,authenticated;
create function public.jf_manage_account(target_user uuid,account_action text,details jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.jf_memberships%rowtype;
begin
 if jioflow_private.is_creator() then return public.jf_manage_account_creator(target_user,account_action,details);end if;
 if not jioflow_private.can_manage_lower(target_user,case when account_action='force_logout' then 'logout' else 'users' end) then raise exception 'This account cannot be managed.' using errcode='42501';end if;
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
end $$;
-- Recovery stays email-based, and existing Agent reset approval checks remain in force.
alter function public.jf_account_email_target(uuid) rename to jf_account_email_target_creator;
revoke all on function public.jf_account_email_target_creator(uuid) from public,anon,authenticated;
create function public.jf_account_email_target(target_user uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if jioflow_private.is_creator() then return public.jf_account_email_target_creator(target_user);end if;
 if not jioflow_private.can_manage_lower(target_user) then raise exception 'Account email access denied.' using errcode='42501';end if;
 if (select count(*) from jioflow_private.account_audit where actor_id=auth.uid() and action='email_action' and created_at>now()-interval '1 minute')>=5 then raise exception 'Wait one minute.';end if;
 insert into jioflow_private.account_audit(actor_id,target_id,action) values(auth.uid(),target_user,'email_action');
 return(select jsonb_build_object('email',email,'pending_email',coalesce(email_change,''),'verified',email_confirmed_at is not null) from auth.users where id=target_user);
end $$;
revoke all on function public.jf_save_profile(uuid,jsonb),public.jf_manage_account(uuid,text,jsonb),public.jf_account_email_target(uuid) from public,anon,authenticated;
grant execute on function public.jf_save_profile(uuid,jsonb),public.jf_manage_account(uuid,text,jsonb),public.jf_account_email_target(uuid) to authenticated;
insert into public.jf_schema_versions(version) values('016_delegated_accounts');

-- 017_history_import.sql
create table public.jf_order_history(
 id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.jf_shops(id) on delete cascade,
 customer_id uuid not null references public.jf_customers(id) on delete cascade,external_id text not null check(length(external_id) between 1 and 200),
 details jsonb not null,updated_at timestamptz not null default now(),unique(shop_id,external_id)
);
create index jf_order_history_customer on public.jf_order_history(shop_id,customer_id,updated_at desc);
create table public.jf_history_jobs(
 id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.jf_shops(id) on delete cascade,
 requested_by uuid references public.jf_profiles(id),file_name text not null,status text not null default 'uploading' check(status in('uploading','ready','processing','completed','cancelled')),
 staged integer not null default 0,processed integer not null default 0,rejected integer not null default 0,created_at timestamptz not null default now()
);
create table public.jf_history_stage(job_id uuid references public.jf_history_jobs(id) on delete cascade,row_number integer not null,payload jsonb not null,done boolean not null default false,error text,primary key(job_id,row_number));
alter table public.jf_order_history enable row level security;alter table public.jf_history_jobs enable row level security;alter table public.jf_history_stage enable row level security;
revoke all on public.jf_order_history,public.jf_history_jobs,public.jf_history_stage from anon,authenticated;
grant select on public.jf_order_history to authenticated;
create policy jf_history_read on public.jf_order_history for select to authenticated using(jioflow_private.can_read_customer(shop_id,customer_id));
create function public.jf_history_import(target_shop uuid,action text,details jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare jid uuid;j public.jf_history_jobs%rowtype;r record;cid uuid;oldcid uuid;n integer;bad integer:=0;good integer:=0;x jsonb;
begin
 if not jioflow_private.has_permission(target_shop,'assign') or not jioflow_private.has_permission(target_shop,'import') or not jioflow_private.reads_staff_operations(target_shop) then raise exception 'Import permission required.' using errcode='42501';end if;
 if action='list' then return coalesce((select jsonb_agg(to_jsonb(t)) from(select * from public.jf_history_jobs where shop_id=target_shop order by created_at desc limit 50)t),'[]');end if;
 if action='create' then
  if length(trim(coalesce(details->>'file_name',''))) not between 1 and 250 then raise exception 'Invalid file name.';end if;
  insert into public.jf_history_jobs(shop_id,requested_by,file_name) values(target_shop,auth.uid(),details->>'file_name') returning id into jid;return jsonb_build_object('id',jid);
 end if;
 jid:=(details->>'job_id')::uuid;select * into j from public.jf_history_jobs where shop_id=target_shop and id=jid for update;if not found then raise exception 'Import job not found.';end if;
 if action='stage' then
  if j.status<>'uploading' or jsonb_typeof(details->'rows')<>'array' or jsonb_array_length(details->'rows')>200 or (details->>'offset')::integer<0 then raise exception 'Invalid upload chunk or job state.';end if;
  n:=(details->>'offset')::integer;for x in select * from jsonb_array_elements(details->'rows') loop
   insert into public.jf_history_stage(job_id,row_number,payload) values(jid,n,x) on conflict do nothing;n:=n+1;
  end loop;
  update public.jf_history_jobs set staged=(select count(*) from public.jf_history_stage where job_id=jid) where id=jid;
 elsif action='ready' then
  if j.status<>'uploading' or j.staged=0 then raise exception 'Upload rows before importing.';end if;
  update public.jf_history_jobs set status='ready' where id=jid;
 elsif action='cancel' then update public.jf_history_jobs set status='cancelled' where id=jid;
 elsif action='process' then
  if j.status not in('ready','processing') then return to_jsonb(j);end if;
  update public.jf_history_jobs set status='processing' where id=jid;
  for r in select * from public.jf_history_stage where job_id=jid and not done order by row_number limit 100 for update loop
   begin
    if length(trim(coalesce(r.payload->>'external_id',''))) not between 1 and 200 or jsonb_typeof(r.payload->'customer')<>'object' then raise exception 'Invoice / Order ID and customer required.';end if;
    cid:=public.jf_save_customer(target_shop,null,r.payload->'customer');
    select customer_id into oldcid from public.jf_order_history where shop_id=target_shop and external_id=trim(r.payload->>'external_id') for update;
    if oldcid is not null and oldcid<>cid then raise exception 'This Order ID belongs to a different phone.';end if;
    insert into public.jf_order_history(shop_id,customer_id,external_id,details) values(target_shop,cid,trim(r.payload->>'external_id'),r.payload-'customer'-'external_id') on conflict(shop_id,external_id) do update set details=excluded.details,updated_at=now();
    update public.jf_history_stage set done=true,payload='{}' where job_id=jid and row_number=r.row_number;good:=good+1;
   exception when others then
    update public.jf_history_stage set done=true,error=case when sqlstate in('22023','P0001') then left(sqlerrm,250) else 'Row validation failed ('||sqlstate||')' end,payload='{}' where job_id=jid and row_number=r.row_number;bad:=bad+1;
   end;
  end loop;
  update public.jf_history_jobs set processed=processed+good+bad,rejected=rejected+bad,status=case when not exists(select 1 from public.jf_history_stage where job_id=jid and not done) then 'completed' else 'processing' end where id=jid;
 elsif action='errors' then return coalesce((select jsonb_agg(jsonb_build_object('row',row_number+2,'error',error)) from(select row_number,error from public.jf_history_stage where job_id=jid and error is not null order by row_number limit 200)t),'[]');
 else raise exception 'Unknown import action.';end if;
 return(select to_jsonb(t) from public.jf_history_jobs t where id=jid);
end $$;
revoke all on function public.jf_history_import(uuid,text,jsonb) from public,anon,authenticated;grant execute on function public.jf_history_import(uuid,text,jsonb) to authenticated;
insert into public.jf_schema_versions(version) values('017_history_import');

-- 018_finance_agent_totals.sql
create function public.jf_agent_totals(target_shop uuid) returns jsonb language sql stable security invoker set search_path='' as $$
 with c as(select c.assigned_membership_id id,count(*) assigned,count(*) filter(where f.status='completed') completed,count(*) filter(where f.status='completed' and exists(select 1 from public.jf_orders x where x.shop_id=c.shop_id and x.customer_id=c.id and x.archived_at is null and x.status not in('draft','cancelled'))) buyers,count(*) filter(where coalesce(f.status,'pending') in('pending','callback')) pending,count(*) filter(where f.status='cancelled') cancelled,count(*) filter(where f.call_outcome in('connected','positive','negative','intermediate')) connected from public.jf_customers c left join public.jf_followups f on f.shop_id=c.shop_id and f.customer_id=c.id where c.shop_id=target_shop and c.archived_at is null group by c.assigned_membership_id),o as(select assigned_membership_id id,count(*) orders,count(*) filter(where status not in('draft','cancelled')) confirmed,count(*) filter(where status='delivered') delivered,count(*) filter(where status='returned') returned,coalesce(sum(total) filter(where status not in('draft','cancelled')),0) revenue from public.jf_orders where shop_id=target_shop and archived_at is null group by assigned_membership_id)
 select coalesce(jsonb_agg(jsonb_build_object('id',coalesce(c.id,o.id),'assigned',coalesce(c.assigned,0),'purchase_rate',case when coalesce(c.completed,0)=0 then 0 else 100.0*c.buyers/c.completed end,'completed',coalesce(c.completed,0),'pending',coalesce(c.pending,0),'cancelled',coalesce(c.cancelled,0),'connected',coalesce(c.connected,0),'orders',coalesce(o.orders,0),'confirmed',coalesce(o.confirmed,0),'delivered',coalesce(o.delivered,0),'returned',coalesce(o.returned,0),'revenue',coalesce(o.revenue,0))),'[]') from c full join o on o.id=c.id;
$$;
create function public.jf_finance_totals(target_shop uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not jioflow_private.has_permission(target_shop,'profit') then raise exception 'Finance access denied.' using errcode='42501';end if;
 with o as(select o.*,coalesce(f.product_cost,(select case when count(*)>0 and count(*)=count(pc.unit_cost) then sum(i.quantity*pc.unit_cost) end from public.jf_order_items i left join public.jf_product_costs pc on pc.shop_id=i.shop_id and pc.product_id=i.product_id where i.shop_id=target_shop and i.order_id=o.id)) product_cost,
 coalesce(f.courier_charge,o.delivery_charge)+coalesce(f.cod_fee,0)+coalesce(f.packaging_cost,0)+coalesce(f.return_cost,0)+coalesce(f.other_cost,0) fees,
 case when o.status='delivered' then greatest(0,coalesce(f.cod_expected,o.total-coalesce((select sum(amount) from public.jf_payments p where p.shop_id=target_shop and p.order_id=o.id and p.status='verified'),0))-coalesce(f.cod_received,0)) else 0 end cod_pending
 from public.jf_orders o left join public.jf_order_finance f on f.shop_id=o.shop_id and f.order_id=o.id where o.shop_id=target_shop and o.archived_at is null and o.status not in('draft','cancelled'))
 select jsonb_build_object('revenue',coalesce(sum(total),0),'product_cost',case when count(*)=count(product_cost) then coalesce(sum(product_cost),0) end,'fees',coalesce(sum(fees),0),'profit',case when count(*)=count(product_cost) then coalesce(sum(total-product_cost-fees),0) end,'cod_pending',coalesce(sum(cod_pending),0),'missing_cost_orders',count(*) filter(where product_cost is null),'agents',(select coalesce(jsonb_object_agg(t.member,t.profit),'{}') from(select coalesce(assigned_membership_id::text,'unassigned') member,case when count(*)=count(product_cost) then sum(total-product_cost-fees) end profit from o group by assigned_membership_id)t)) into result from o;
 return result;
end $$;
revoke all on function public.jf_agent_totals(uuid),public.jf_finance_totals(uuid) from public,anon,authenticated;
grant execute on function public.jf_agent_totals(uuid),public.jf_finance_totals(uuid) to authenticated;
insert into public.jf_schema_versions(version) values('018_finance_agent_totals');

commit;
