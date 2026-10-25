-- Apply once after 008. Managed Agents, approval per Auth session, Creator shop controls.
begin;
do $$ begin if not exists(select 1 from public.jf_schema_versions where version='008_profile_editing') then
-- Accept the exact 008 version registered by the installed migration.
 if not exists(select 1 from public.jf_schema_versions where version like '008_%') then raise exception 'Apply migration 008 first.'; end if;
end if; end $$;
alter table public.jf_profiles add column managed_agent boolean not null default false;
alter table public.jf_shops add column archived_at timestamptz;
create unique index jf_agent_jio_id on public.jf_profiles(lower(user_code)) where managed_agent and deleted_at is null;
create table public.jf_agent_sessions (
 session_id uuid primary key, user_id uuid not null references public.jf_profiles(id),
 shop_id uuid not null references public.jf_shops(id), device_id text not null,
 status text not null default 'pending' check(status in ('pending','approved','denied','revoked')),
 requested_at timestamptz not null default now(), decided_at timestamptz, decided_by uuid references public.jf_profiles(id)
);
create index jf_agent_sessions_queue on public.jf_agent_sessions(shop_id,status,requested_at desc);
alter table public.jf_agent_sessions enable row level security;
revoke all on public.jf_agent_sessions from public,anon,authenticated;
grant select on public.jf_agent_sessions to authenticated;
create policy jf_agent_sessions_read on public.jf_agent_sessions for select to authenticated
 using(jioflow_private.manages_shop(shop_id));

-- Force logout/deactivation must also remove stale approval requests from the queue.
create function jioflow_private.sync_agent_revocation() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 update public.jf_agent_sessions set status='revoked',decided_at=new.revoked_at,decided_by=new.revoked_by where session_id=new.session_id and status in ('pending','approved');
 return new;
end $$;
revoke all on function jioflow_private.sync_agent_revocation() from public,anon,authenticated;
create trigger jf_sync_agent_revocation after insert on jioflow_private.revoked_sessions for each row execute function jioflow_private.sync_agent_revocation();

create function jioflow_private.agent_member(sid uuid) returns uuid
language sql stable security definer set search_path='' as $$
 select m.id from public.jf_memberships m join public.jf_shops s on s.id=m.shop_id
 where m.user_id=auth.uid() and m.shop_id=sid and m.role='agent' and m.status='active' and s.active
 and jioflow_private.session_allowed()
 and exists(select 1 from public.jf_agent_sessions a where a.user_id=auth.uid() and a.shop_id=sid
 and a.session_id::text=auth.jwt()->>'session_id' and a.status='approved') limit 1;
$$;
revoke all on function jioflow_private.agent_member(uuid) from public,anon,authenticated;

create function public.jf_validate_agent_id(jio_id text) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if not jioflow_private.session_allowed() or not exists(select 1 from public.jf_shops where jioflow_private.can_provision(id,'agent')) then raise exception 'Access denied.' using errcode='42501'; end if;
 if jio_id !~ '^[A-Za-z0-9_-]{3,50}$' then raise exception 'Enter a valid Jio ID.' using errcode='22023'; end if;
 if exists(select 1 from public.jf_profiles where lower(user_code)=lower(jio_id) and managed_agent and deleted_at is null) then raise exception 'Jio ID already exists.' using errcode='23505'; end if;
 return true;
end $$;
create function public.jf_finish_agent(request_id uuid,agent_user uuid,jio_id text) returns uuid
language plpgsql security definer set search_path='' as $$
declare r public.jf_account_requests%rowtype;
begin
 select * into r from public.jf_account_requests where id=request_id and actor_id=auth.uid() for update;
 if not found or r.account_role<>'agent' or r.completed_at is not null or r.created_at<now()-interval '15 minutes' or not jioflow_private.can_provision(r.shop_id,'agent') then raise exception 'Agent request is invalid.' using errcode='42501'; end if;
 perform public.jf_validate_agent_id(jio_id);
 if not exists(select 1 from auth.users where id=agent_user and lower(email)=r.email and email_confirmed_at is not null) then raise exception 'Agent identity mismatch.' using errcode='42501'; end if;
 insert into public.jf_profiles(id,full_name,email,phone,user_code,managed_agent,email_verified_at)
 values(agent_user,r.full_name,r.email,'',jio_id,true,null);
 insert into public.jf_memberships(shop_id,user_id,role,status,permissions)
 values(r.shop_id,agent_user,'agent','pending','{"assign":true,"price":true,"discount":true,"advance":true,"booking":true}');
 update public.jf_account_requests set user_id=agent_user,completed_at=now() where id=r.id;
 return agent_user;
end $$;

create function public.jf_agent_session(device_id text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.jf_memberships%rowtype; a public.jf_agent_sessions%rowtype; sid uuid;
begin
 if not jioflow_private.session_allowed() then raise exception 'Sign in again.' using errcode='42501'; end if;
 select * into m from public.jf_memberships where user_id=auth.uid() and role='agent' and status<>'removed';
 if not found then return jsonb_build_object('is_agent',false); end if;
 if m.status='disabled' or not exists(select 1 from public.jf_shops where id=m.shop_id and active) then raise exception 'Workspace access is disabled.' using errcode='42501'; end if;
 if length(device_id) not between 16 and 100 then raise exception 'Device identity is required.' using errcode='22023'; end if;
 sid:=(auth.jwt()->>'session_id')::uuid;
 insert into public.jf_agent_sessions(session_id,user_id,shop_id,device_id) values(sid,auth.uid(),m.shop_id,device_id) on conflict(session_id) do nothing;
 select * into a from public.jf_agent_sessions where session_id=sid;
 if a.device_id<>device_id or a.shop_id<>m.shop_id or a.user_id<>auth.uid() then raise exception 'This session belongs to another device.' using errcode='42501'; end if;
 return jsonb_build_object('is_agent',true,'status',a.status,'shop_id',m.shop_id,'shop_name',(select name from public.jf_shops where id=m.shop_id));
end $$;
create function public.jf_approve_agent(target_session uuid,approve boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.jf_agent_sessions%rowtype;
begin
 -- Lock the Agent profile first: approvals from concurrent Admins cannot admit two sessions.
 perform 1 from public.jf_profiles where id=(select user_id from public.jf_agent_sessions where session_id=target_session) for update;
 select * into a from public.jf_agent_sessions where session_id=target_session for update;
 if not found or not jioflow_private.manages_shop(a.shop_id) then raise exception 'Approval is not permitted.' using errcode='42501'; end if;
 if a.status<>'pending' then raise exception 'This request is no longer pending.' using errcode='22023'; end if;
 if not exists(select 1 from auth.sessions where id=a.session_id and user_id=a.user_id) or exists(select 1 from jioflow_private.revoked_sessions where session_id=a.session_id) or not exists(select 1 from public.jf_profiles where id=a.user_id and active and deleted_at is null) or not exists(select 1 from public.jf_memberships where user_id=a.user_id and shop_id=a.shop_id and role='agent' and status in ('active','pending')) then raise exception 'Agent access has changed.' using errcode='42501'; end if;
 if approve then
  insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by)
   select s.id,a.user_id,auth.uid() from auth.sessions s where s.user_id=a.user_id and s.id<>a.session_id on conflict do nothing;
  update public.jf_agent_sessions set status='revoked',decided_at=now(),decided_by=auth.uid() where user_id=a.user_id and session_id<>a.session_id and status in ('approved','pending');
  update public.jf_memberships set status='active' where user_id=a.user_id and shop_id=a.shop_id and role='agent';
 end if;
 update public.jf_agent_sessions set status=case when approve then 'approved' else 'denied' end,decided_at=now(),decided_by=auth.uid() where session_id=a.session_id;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),a.user_id,case when approve then 'approve_login' else 'deny_login' end,jsonb_build_object('session_id',a.session_id,'shop_id',a.shop_id));
 return jsonb_build_object('message',case when approve then 'Agent login approved. Other sessions were signed out.' else 'Agent login denied.' end);
end $$;
create function public.jf_end_agent_session() returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if not jioflow_private.session_allowed() then return false; end if;
 if exists(select 1 from public.jf_memberships where user_id=auth.uid() and role='agent' and status<>'removed') then
  insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by) values((auth.jwt()->>'session_id')::uuid,auth.uid(),auth.uid()) on conflict do nothing;
  update public.jf_agent_sessions set status='revoked',decided_at=now(),decided_by=auth.uid() where session_id::text=auth.jwt()->>'session_id' and user_id=auth.uid();
 end if;
 return true;
end $$;

-- Existing staff checks stay intact. Agent access additionally needs session approval.
alter function jioflow_private.reads_operations(uuid) rename to reads_staff_operations;
create function jioflow_private.reads_operations(target_shop uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select jioflow_private.reads_staff_operations(target_shop) or jioflow_private.agent_member(target_shop) is not null;
$$;
alter function jioflow_private.in_shop(uuid) rename to in_shop_before_agent_sessions;
create function jioflow_private.in_shop(target_shop uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select jioflow_private.in_shop_before_agent_sessions(target_shop) and
 (not exists(select 1 from public.jf_memberships where user_id=auth.uid() and shop_id=target_shop and role='agent' and status<>'removed') or jioflow_private.agent_member(target_shop) is not null);
$$;
alter function jioflow_private.has_permission(uuid,text) rename to staff_has_permission;
create function jioflow_private.has_permission(sid uuid,permission_name text) returns boolean
language sql stable security definer set search_path='' as $$
 select jioflow_private.staff_has_permission(sid,permission_name) or
 (permission_name in ('assign','price','discount','advance','booking','pull') and exists(select 1 from public.jf_memberships where id=jioflow_private.agent_member(sid) and permissions->permission_name='true'::jsonb));
$$;
create function jioflow_private.can_read_customer(sid uuid,cid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select jioflow_private.reads_staff_operations(sid) or exists(select 1 from public.jf_customers where shop_id=sid and id=cid and assigned_membership_id=jioflow_private.agent_member(sid));
$$;
create function jioflow_private.can_read_order(sid uuid,oid uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select jioflow_private.reads_staff_operations(sid) or exists(select 1 from public.jf_orders where shop_id=sid and id=oid and jioflow_private.agent_member(sid) is not null and (entered_by=auth.uid() or assigned_membership_id=jioflow_private.agent_member(sid)));
$$;
-- Replace all broad operational read policies before enabling Agents.
do $$ declare t text; pred text; begin
 foreach t in array array['jf_customers','jf_products','jf_followups','jf_followup_events','jf_notes','jf_orders','jf_order_items','jf_order_events','jf_groups','jf_group_members','jf_payments','jf_shipments','jf_courier_events','jf_import_jobs'] loop
  pred:=case
   when t='jf_customers' then 'jioflow_private.can_read_customer(shop_id,id)'
   when t='jf_products' then 'jioflow_private.reads_staff_operations(shop_id) or (jioflow_private.agent_member(shop_id) is not null and active and archived_at is null)'
   when t='jf_followups' then 'jioflow_private.can_read_customer(shop_id,customer_id)'
   when t='jf_followup_events' then 'exists(select 1 from public.jf_followups f where f.id=followup_id and f.shop_id=jf_followup_events.shop_id and jioflow_private.can_read_customer(f.shop_id,f.customer_id))'
   when t='jf_notes' then 'jioflow_private.can_read_customer(shop_id,customer_id)'
   when t='jf_orders' then 'jioflow_private.can_read_order(shop_id,id)'
   when t in ('jf_order_items','jf_order_events','jf_payments','jf_shipments') then 'jioflow_private.can_read_order(shop_id,order_id)'
   when t='jf_courier_events' then 'exists(select 1 from public.jf_shipments s where s.id=shipment_id and s.shop_id=jf_courier_events.shop_id and jioflow_private.can_read_order(s.shop_id,s.order_id))'
   else 'jioflow_private.reads_staff_operations(shop_id)' end;
  execute format('drop policy if exists %I on public.%I',t||'_read',t);
  execute format('create policy %I on public.%I for select to authenticated using (%s)',t||'_read',t,pred);
 end loop;
end $$;

-- Provider confirmation used for managed Agents is not verified contact mail.
create or replace function jioflow_private.sync_verified_email() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 update public.jf_profiles set email=new.email,
  pending_email=nullif(new.email_change,''),
  email_verified_at=case when managed_agent and new.email is not distinct from old.email then null else new.email_confirmed_at end,
  managed_agent=case when managed_agent and new.email is distinct from old.email and new.email_confirmed_at is not null then false else managed_agent end
 where id=new.id;
 return new;
end $$;
-- A managed Agent cannot be promoted using a fictitious confirmed address.
alter function public.jf_save_profile(uuid,jsonb) rename to jf_save_profile_before_agent_sessions;
revoke all on function public.jf_save_profile_before_agent_sessions(uuid,jsonb) from public,anon,authenticated;
create function public.jf_save_profile(target_user uuid,details jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.jf_profiles where id=target_user and managed_agent) and details->>'role' in ('owner','admin') then raise exception 'Verify a real contact email before promoting this Agent.' using errcode='42501'; end if;
 if exists(select 1 from public.jf_profiles where id=target_user and managed_agent) and details ? 'user_code' and coalesce(details->>'user_code','') !~ '^[A-Za-z0-9_-]{3,50}$' then raise exception 'Enter a valid Jio ID.' using errcode='22023'; end if;
 return public.jf_save_profile_before_agent_sessions(target_user,details);
end $$;

create function public.jf_manage_shop(target_shop uuid,shop_action text,details jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.jf_shops%rowtype;
begin
 if not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501'; end if;
 select * into s from public.jf_shops where id=target_shop for update;
 if not found then raise exception 'Shop not found.' using errcode='P0002'; end if;
 if shop_action='edit' then
  if jsonb_typeof(details) is distinct from 'object' or exists(select 1 from jsonb_object_keys(details) k where k not in ('name','email','phone','address','website','logo_path')) or length(trim(coalesce(details->>'name',s.name))) not between 1 and 120 or length(coalesce(details->>'email',''))>254 or length(coalesce(details->>'phone',''))>30 or length(coalesce(details->>'address',''))>1000 or length(coalesce(details->>'website',''))>500 or length(coalesce(details->>'logo_path',''))>350000 or (details ? 'logo_path' and details->>'logo_path'<>'' and details->>'logo_path' !~ '^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$') then raise exception 'Check the shop details.' using errcode='22023'; end if;
  update public.jf_shops set name=trim(coalesce(details->>'name',name)),email=coalesce(details->>'email',email),phone=coalesce(details->>'phone',phone),address=coalesce(details->>'address',address),website=coalesce(details->>'website',website),logo_path=coalesce(details->>'logo_path',logo_path) where id=target_shop;
 elsif shop_action in ('archive','restore') then
  if details->>'confirmation' is distinct from s.name then raise exception 'Type the business name to confirm.' using errcode='22023'; end if;
  update public.jf_shops set active=shop_action='restore',archived_at=case when shop_action='archive' then now() end where id=target_shop;
  if shop_action='archive' then
   insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by) select x.id,x.user_id,auth.uid() from auth.sessions x where x.user_id<>auth.uid() and (x.user_id=s.owner_id or exists(select 1 from public.jf_memberships where shop_id=target_shop and user_id=x.user_id and status<>'removed')) on conflict do nothing;
   update public.jf_agent_sessions set status='revoked',decided_at=now(),decided_by=auth.uid() where shop_id=target_shop and status in ('pending','approved');
  end if;
 else raise exception 'Unsupported shop action.' using errcode='22023'; end if;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),auth.uid(),'shop_'||shop_action,jsonb_build_object('shop_id',target_shop));
 return jsonb_build_object('message',case shop_action when 'archive' then 'Shop deleted from active workspaces. History is preserved; Creator can restore it.' when 'restore' then 'Shop restored.' else 'Shop details saved.' end);
end $$;

create or replace function public.jf_save_customer(target_shop uuid, customer_id uuid default null, details jsonb default '{}'::jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare cid uuid; normalized text; assigned uuid; is_permanent boolean; old public.jf_customers%rowtype;
begin
 if not jioflow_private.has_permission(target_shop,'assign') then raise exception 'Customer editing is not permitted.' using errcode='42501'; end if;
 if jsonb_typeof(details)<>'object' or length(coalesce(details->>'phone',''))>80 or length(trim(coalesce(details->>'full_name',''))) not between 1 and 120 or length(coalesce(details->>'email',''))>254 or length(coalesce(details->>'address',''))>1000 or length(coalesce(details->>'district',''))>100 or length(coalesce(details->>'area',''))>100 or length(coalesce(details->>'source',''))>100 then raise exception 'Check the customer details.' using errcode='22023'; end if;
 normalized := jioflow_private.normalize_phone(details->>'phone');
 -- Serialize same-phone upserts so duplicate form submissions use one profile.
 perform pg_advisory_xact_lock(hashtextextended(target_shop::text||normalized,0));
 if customer_id is not null then
  select * into old from public.jf_customers where shop_id=target_shop and id=customer_id and archived_at is null for update;
  if not found then raise exception 'Customer not found in this business.' using errcode='P0002'; end if;
 else
  select * into old from public.jf_customers where shop_id=target_shop and phone=normalized for update;
  if old.archived_at is not null then raise exception 'This customer is archived. Restore it before editing.' using errcode='22023'; end if;
 end if;
 assigned := case when details ? 'assigned_membership_id' then nullif(details->>'assigned_membership_id','')::uuid else old.assigned_membership_id end;
 is_permanent := coalesce((details->>'permanent')::boolean,old.permanent,false);
 if jioflow_private.agent_member(target_shop) is not null then
  if old.id is not null and old.assigned_membership_id is distinct from jioflow_private.agent_member(target_shop) then raise exception 'This customer belongs to another queue.' using errcode='42501'; end if;
  if assigned is not null and assigned<>jioflow_private.agent_member(target_shop) then raise exception 'Agents cannot assign other users.' using errcode='42501'; end if;
  if is_permanent is distinct from coalesce(old.permanent,false) then raise exception 'Permanent client assignment requires an administrator.' using errcode='42501'; end if;
  assigned:=jioflow_private.agent_member(target_shop);
 end if;
 if assigned is not null and not exists(select 1 from public.jf_memberships m join public.jf_profiles p on p.id=m.user_id where m.id=assigned and m.shop_id=target_shop and m.role='agent' and m.status='active' and p.active and p.deleted_at is null) then raise exception 'Select an active Agent in this business.' using errcode='22023'; end if;
 if is_permanent and assigned is null then raise exception 'Assign an Agent before marking a permanent client.' using errcode='22023'; end if;
 if old.id is null then
  insert into public.jf_customers(shop_id,phone,full_name,email,address,district,area,source,assigned_membership_id,permanent)
  values(target_shop,normalized,trim(details->>'full_name'),coalesce(details->>'email',''),coalesce(details->>'address',''),coalesce(details->>'district',''),coalesce(details->>'area',''),coalesce(nullif(details->>'source',''),'manual'),assigned,is_permanent) returning id into cid;
 else
  update public.jf_customers set phone=normalized,full_name=trim(details->>'full_name'),email=coalesce(details->>'email',email),address=coalesce(details->>'address',address),district=coalesce(details->>'district',district),area=coalesce(details->>'area',area),source=coalesce(nullif(details->>'source',''),source),assigned_membership_id=assigned,permanent=is_permanent,updated_at=now() where id=old.id returning id into cid;
 end if;
 insert into public.jf_followups(shop_id,customer_id) values(target_shop,cid) on conflict on constraint jf_followups_shop_id_customer_id_key do nothing;
 return cid;
end $$;
create or replace function public.jf_record_followup(target_shop uuid, customer_id uuid, followup_status text, call_result text default null, callback_time timestamptz default null, note_text text default '') returns uuid
language plpgsql security definer set search_path = '' as $$
declare fid uuid;
begin
 if not jioflow_private.has_permission(target_shop,'assign') then raise exception 'Follow-up editing is not permitted.' using errcode='42501'; end if;
 if not jioflow_private.can_read_customer(target_shop,customer_id) then raise exception 'Customer access denied.' using errcode='42501'; end if;
 if followup_status not in ('pending','callback','completed','cancelled') or followup_status is null or length(note_text)>10000 then raise exception 'Check the follow-up status and note.' using errcode='22023'; end if;
 if call_result is not null and call_result not in ('not_attempted','no_answer','busy','not_connected','connected','positive','negative','intermediate') then raise exception 'Choose a valid call outcome.' using errcode='22023'; end if;
 if followup_status='callback' and callback_time is null then raise exception 'Select a callback date and time.' using errcode='22023'; end if;
 perform 1 from public.jf_customers where shop_id=target_shop and id=customer_id and archived_at is null for update;
 if not found then raise exception 'Customer not found in this business.' using errcode='P0002'; end if;
 insert into public.jf_followups(shop_id,customer_id,status,call_outcome,callback_at,last_contact_at,updated_by)
 values(target_shop,customer_id,followup_status,call_result,case when followup_status='callback' then callback_time end,now(),auth.uid())
 on conflict on constraint jf_followups_shop_id_customer_id_key do update set status=excluded.status,call_outcome=excluded.call_outcome,callback_at=excluded.callback_at,last_contact_at=excluded.last_contact_at,updated_by=excluded.updated_by,updated_at=now() returning id into fid;
 insert into public.jf_followup_events(shop_id,followup_id,actor_id,outcome,note,callback_at)
 values(target_shop,fid,auth.uid(),coalesce(call_result,followup_status),coalesce(note_text,''),case when followup_status='callback' then callback_time end);
 if length(trim(coalesce(note_text,'')))>0 then insert into public.jf_notes(shop_id,customer_id,body,author_id) values(target_shop,customer_id,trim(note_text),auth.uid()); end if;
 return fid;
end $$;
create or replace function public.jf_save_order(target_shop uuid,request_id uuid,details jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare oid uuid; cid uuid; pid uuid; item jsonb; p public.jf_products%rowtype; subtotal_value numeric:=0; price_value numeric; qty integer; discount_value numeric; delivery_value numeric; advance_value numeric; member_id uuid; parent_id uuid; phone_value text; status_value text; item_count int;
begin
 if not jioflow_private.has_permission(target_shop,'assign') then raise exception 'Order entry is not permitted.' using errcode='42501'; end if;
 if request_id is null then raise exception 'Order request ID is required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(target_shop::text||request_id::text,0));
 select id into oid from public.jf_orders where shop_id=target_shop and request_key=request_id;
 if oid is not null then if not jioflow_private.can_read_order(target_shop,oid) then raise exception 'Order access denied.' using errcode='42501'; end if; return oid; end if;
 if jsonb_typeof(details) is distinct from 'object' or jsonb_typeof(details->'items') is distinct from 'array' then raise exception 'Enter order details and products.'; end if;
 item_count:=jsonb_array_length(details->'items');if item_count<1 or item_count>1000 then raise exception 'Choose order items (up to 1000 line items per submission).'; end if;
 if length(trim(coalesce(details->>'full_name',''))) not between 1 and 120 or length(trim(coalesce(details->>'address',''))) not between 1 and 1000 or length(coalesce(details->>'note',''))>10000 then raise exception 'Check customer name, address and note.'; end if;
 phone_value:=jioflow_private.normalize_phone(details->>'phone');
 status_value:=coalesce(details->>'status','draft');if status_value not in ('draft','confirmed','ready_to_book') then raise exception 'Choose Draft, Confirmed or Ready to Book.'; end if;
 if coalesce(details->>'order_type','new') not in ('new','exchange','replacement') then raise exception 'Choose a valid order type.'; end if;
 if coalesce(details->>'source','manual') not in ('manual','phone','website','facebook','whatsapp','repeat_customer') then raise exception 'Choose a valid source.'; end if;
 foreach pid in array array(select distinct (v->>'product_id')::uuid from jsonb_array_elements(details->'items') v order by 1) loop
  perform 1 from public.jf_products where id=pid and shop_id=target_shop and active and archived_at is null for share;
  if not found then raise exception 'A product is inactive or outside this business.'; end if;
 end loop;
 for item in select * from jsonb_array_elements(details->'items') loop
  if coalesce(item->>'quantity','') !~ '^[1-9][0-9]{0,5}$' or coalesce(item->>'unit_price','') !~ '^[0-9]{1,10}(\.[0-9]{1,2})?$' then raise exception 'Check item quantity and price.'; end if;
  qty:=(item->>'quantity')::int;price_value:=(item->>'unit_price')::numeric;
  if jioflow_private.agent_member(target_shop) is not null and not jioflow_private.has_permission(target_shop,'price') and not exists(select 1 from public.jf_products where id=(item->>'product_id')::uuid and shop_id=target_shop and sale_price=price_value) then raise exception 'Price changes are not permitted.' using errcode='42501'; end if;
  subtotal_value:=subtotal_value+qty*price_value;
 end loop;
 if subtotal_value>999999999999 then raise exception 'Order amount is too large.'; end if;
 if coalesce(details->>'discount','0') !~ '^[0-9]{1,12}(\.[0-9]{1,2})?$' or coalesce(details->>'delivery_charge','0') !~ '^[0-9]{1,12}(\.[0-9]{1,2})?$' or coalesce(details->>'advance','0') !~ '^[0-9]{1,12}(\.[0-9]{1,2})?$' then raise exception 'Check discount, delivery and advance amounts.'; end if;
 discount_value:=coalesce(details->>'discount','0')::numeric;delivery_value:=coalesce(details->>'delivery_charge','0')::numeric;advance_value:=coalesce(details->>'advance','0')::numeric;
 if jioflow_private.agent_member(target_shop) is not null and ((discount_value>0 and not jioflow_private.has_permission(target_shop,'discount')) or (advance_value>0 and not jioflow_private.has_permission(target_shop,'advance'))) then raise exception 'Discount or advance access denied.' using errcode='42501'; end if;
 if discount_value>subtotal_value or advance_value>subtotal_value-discount_value+delivery_value then raise exception 'Discount or advance exceeds the order amount.'; end if;
 if advance_value>0 and (coalesce(details->>'payment_method','') not in ('bKash','Nagad','Bank Transfer','Cash') or length(trim(coalesce(details->>'transaction_id','')))=0) then raise exception 'Advance payment requires a method and transaction ID.'; end if;
 parent_id:=nullif(details->>'original_order_id','')::uuid;
 if coalesce(details->>'order_type','new')<>'new' and parent_id is null then raise exception 'Select the original order for exchange or replacement.'; end if;
 if parent_id is not null and not exists(select 1 from public.jf_orders where id=parent_id and shop_id=target_shop) then raise exception 'Original order not found in this business.'; end if;
 if parent_id is not null and not jioflow_private.can_read_order(target_shop,parent_id) then raise exception 'Original order access denied.' using errcode='42501'; end if;
 member_id:=nullif(details->>'assigned_membership_id','')::uuid;
 if jioflow_private.agent_member(target_shop) is not null then
  if member_id is not null and member_id<>jioflow_private.agent_member(target_shop) then raise exception 'Agents cannot assign another user.' using errcode='42501'; end if;
  member_id:=jioflow_private.agent_member(target_shop);
 end if;
 if member_id is not null and not exists(select 1 from public.jf_memberships m join public.jf_profiles pr on pr.id=m.user_id where m.id=member_id and m.shop_id=target_shop and m.role='agent' and m.status='active' and pr.active and pr.deleted_at is null) then raise exception 'Choose an active Agent in this business.'; end if;
 cid:=public.jf_save_customer(target_shop,null,jsonb_build_object('full_name',details->>'full_name','phone',phone_value,'address',details->>'address','area',coalesce(details->>'area',''),'source',coalesce(details->>'source','manual')));
 if member_id is null then select assigned_membership_id into member_id from public.jf_customers where id=cid; end if;
 oid:=gen_random_uuid();
 insert into public.jf_orders(id,shop_id,customer_id,order_number,request_key,assigned_membership_id,entered_by,status,source,recipient_name,recipient_phone,delivery_address,area,subtotal,discount,delivery_charge,shipping_note,order_type,original_order_id,preferred_courier,confirmed_at)
 values(oid,target_shop,cid,'JF-'||upper(replace(oid::text,'-','')),request_id,member_id,auth.uid(),status_value,coalesce(details->>'source','manual'),trim(details->>'full_name'),phone_value,trim(details->>'address'),coalesce(details->>'area',''),subtotal_value,discount_value,delivery_value,coalesce(details->>'note',''),coalesce(details->>'order_type','new'),parent_id,left(coalesce(details->>'courier',''),100),case when status_value<>'draft' then now() end);
 for item in select * from jsonb_array_elements(details->'items') loop
  select * into p from public.jf_products where id=(item->>'product_id')::uuid and shop_id=target_shop;
  insert into public.jf_order_items(shop_id,order_id,product_id,product_name,quantity,unit_price) values(target_shop,oid,p.id,p.name,(item->>'quantity')::int,(item->>'unit_price')::numeric);
 end loop;
 if advance_value>0 then insert into public.jf_payments(shop_id,order_id,amount,method,transaction_id,recorded_by) values(target_shop,oid,advance_value,details->>'payment_method',trim(details->>'transaction_id'),auth.uid());end if;
 insert into public.jf_order_events(shop_id,order_id,actor_id,status,note) values(target_shop,oid,auth.uid(),status_value,'Order created');
 return oid;
end $$;
create or replace function public.jf_update_order(target_shop uuid,target_order uuid,details jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare old public.jf_orders%rowtype; next_status text; assigned uuid;
begin
 if not jioflow_private.has_permission(target_shop,'assign') then raise exception 'Order editing is not permitted.' using errcode='42501'; end if;
 if jsonb_typeof(details) is distinct from 'object' or exists(select 1 from jsonb_object_keys(details) k where k not in ('status','note','assigned_membership_id')) then raise exception 'Unsupported order field.'; end if;
 select * into old from public.jf_orders where id=target_order and shop_id=target_shop for update;if not found then raise exception 'Order not found.'; end if;
 if not jioflow_private.can_read_order(target_shop,target_order) then raise exception 'Order access denied.' using errcode='42501'; end if;
 if old.status not in ('draft','confirmed','ready_to_book') then raise exception 'This order requires courier-aware changes.';end if;
 next_status:=coalesce(details->>'status',old.status);if next_status not in ('draft','confirmed','ready_to_book','cancelled') then raise exception 'Choose a supported order status.';end if;
 if length(coalesce(details->>'note',''))>10000 then raise exception 'Note is too long.';end if;
 assigned:=case when details ? 'assigned_membership_id' then nullif(details->>'assigned_membership_id','')::uuid else old.assigned_membership_id end;
 if jioflow_private.agent_member(target_shop) is not null and assigned is distinct from old.assigned_membership_id then raise exception 'Agents cannot reassign orders.' using errcode='42501'; end if;
 if assigned is not null and not exists(select 1 from public.jf_memberships m join public.jf_profiles pr on pr.id=m.user_id where m.id=assigned and m.shop_id=target_shop and m.role='agent' and m.status='active' and pr.active and pr.deleted_at is null) then raise exception 'Choose an active Agent in this business.';end if;
 update public.jf_orders set status=next_status,assigned_membership_id=assigned,shipping_note=coalesce(details->>'note',shipping_note),updated_at=now(),confirmed_at=case when next_status in ('confirmed','ready_to_book') then coalesce(confirmed_at,now()) else confirmed_at end where id=old.id;
 insert into public.jf_order_events(shop_id,order_id,actor_id,status,note) values(target_shop,old.id,auth.uid(),next_status,'Order details updated');return old.id;
end $$;

revoke all on function jioflow_private.reads_operations(uuid),jioflow_private.in_shop(uuid),jioflow_private.has_permission(uuid,text),jioflow_private.can_read_customer(uuid,uuid),jioflow_private.can_read_order(uuid,uuid) from public,anon,authenticated;
grant execute on function jioflow_private.reads_operations(uuid),jioflow_private.in_shop(uuid),jioflow_private.can_read_customer(uuid,uuid),jioflow_private.can_read_order(uuid,uuid),jioflow_private.agent_member(uuid),jioflow_private.reads_staff_operations(uuid) to authenticated;
revoke all on function public.jf_validate_agent_id(text),public.jf_finish_agent(uuid,uuid,text),public.jf_agent_session(text),public.jf_approve_agent(uuid,boolean),public.jf_end_agent_session(),public.jf_manage_shop(uuid,text,jsonb),public.jf_save_profile(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.jf_validate_agent_id(text),public.jf_finish_agent(uuid,uuid,text),public.jf_agent_session(text),public.jf_approve_agent(uuid,boolean),public.jf_end_agent_session(),public.jf_manage_shop(uuid,text,jsonb),public.jf_save_profile(uuid,jsonb) to authenticated;
alter table public.jf_orders add column archived_at timestamptz;
create function public.jf_creator_archive(target_shop uuid,entity text,record_id uuid,restore boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501'; end if;
 if entity='product' then
  update public.jf_products set archived_at=case when restore then null else now() end,active=restore,updated_at=now() where id=record_id and shop_id=target_shop;
 elsif entity='customer' then
  update public.jf_customers set archived_at=case when restore then null else now() end,updated_at=now() where id=record_id and shop_id=target_shop;
 elsif entity='order' then
  -- Archiving changes visibility only. It never cancels a courier or rewrites settlement history.
  update public.jf_orders set archived_at=case when restore then null else now() end,updated_at=now() where id=record_id and shop_id=target_shop;
 else raise exception 'Choose a supported record.' using errcode='22023'; end if;
 if not found then raise exception 'Record not found in this shop.' using errcode='P0002'; end if;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),auth.uid(),case when restore then 'restore_record' else 'archive_record' end,jsonb_build_object('shop_id',target_shop,'entity',entity,'record_id',record_id));
 return jsonb_build_object('message',case when restore then 'Record restored.' else 'Record removed from active lists. History is preserved. Archiving does not cancel a courier booking.' end);
end $$;
revoke all on function public.jf_creator_archive(uuid,text,uuid,boolean) from public,anon,authenticated;
grant execute on function public.jf_creator_archive(uuid,text,uuid,boolean) to authenticated;

insert into public.jf_schema_versions(version) values('009_agent_sessions_shops');
commit;
