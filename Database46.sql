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
