begin;
alter table public.jf_agent_sessions add column if not exists removed_at191 timestamptz;
-- Preserve history, revoke any legacy duplicate approved sessions before adding the invariant.
with ranked as (select session_id,user_id,coalesce(decided_by,(select owner_id from public.jf_shops where id=shop_id),user_id) revoked_by,row_number() over(partition by user_id order by decided_at desc nulls last,requested_at desc,session_id) n from public.jf_agent_sessions where status='approved')
insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by) select session_id,user_id,revoked_by from ranked where n>1 on conflict do nothing;
with ranked as (select session_id,row_number() over(partition by user_id order by decided_at desc nulls last,requested_at desc,session_id) n from public.jf_agent_sessions where status='approved')
update public.jf_agent_sessions a set status='revoked' from ranked r where a.session_id=r.session_id and r.n>1;
create unique index if not exists jf_agent_one_approved191 on public.jf_agent_sessions(user_id) where status='approved';
CREATE OR REPLACE FUNCTION public.jf_agent_devices167(target_user uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare m public.jf_memberships%rowtype;result jsonb;begin
 select * into m from public.jf_memberships where user_id=target_user and role='agent' and status<>'removed';
 if not found or not jioflow_private.session_allowed() or not (
 target_user=auth.uid() or jioflow_private.is_creator() or jioflow_private.owns_shop(m.shop_id) or exists(select 1 from public.jf_memberships a where a.shop_id=m.shop_id and a.user_id=auth.uid() and a.role='admin' and a.status='active') or jioflow_private.manages_shop(m.shop_id)) then
 raise exception 'Agent device access denied.' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(t)),'[]') into result from (
 select a.session_id,(target_user<>auth.uid() and (jioflow_private.is_creator() or jioflow_private.owns_shop(m.shop_id) or exists(select 1 from public.jf_memberships admin191 where admin191.shop_id=m.shop_id and admin191.user_id=auth.uid() and admin191.role='admin' and admin191.status='active') or jioflow_private.can_manage_lower(target_user,'logout'))) as can_remove191,a.status,a.requested_at,a.decided_at,a.device_details141 as device,
 exists(select 1 from auth.sessions s where s.id=a.session_id and s.user_id=a.user_id) as session_valid,
 case when a.status='approved' then p.last_seen end as last_seen,
 (a.status='approved' and p.last_seen>now()-interval '90 seconds' and exists(select 1 from auth.sessions s where s.id=a.session_id and s.user_id=a.user_id) and not exists(select 1 from jioflow_private.revoked_sessions r where r.session_id=a.session_id) and exists(select 1 from public.jf_profiles u where u.id=a.user_id and u.active and u.deleted_at is null)) as online
 from public.jf_agent_sessions a left join jioflow_private.agent_presence135 p on p.shop_id=a.shop_id and p.user_id=a.user_id
 where a.shop_id=m.shop_id and a.user_id=target_user and a.removed_at191 is null order by a.requested_at desc limit 20)t;
 return result;
end $function$
;
create or replace function public.jf_remove_agent_device191(target_session uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.jf_agent_sessions%rowtype;u uuid;begin
 if not coalesce(jioflow_private.session_allowed(),false) then raise exception 'Session access required.' using errcode='42501';end if;
 select user_id into u from public.jf_agent_sessions where session_id=target_session;
 perform 1 from public.jf_profiles where id=u for update;
 select * into a from public.jf_agent_sessions where session_id=target_session for update;
 if not found or a.user_id=auth.uid() or not exists(select 1 from public.jf_memberships m where m.user_id=a.user_id and m.shop_id=a.shop_id and m.role='agent' and m.status<>'removed') or not (jioflow_private.is_creator() or jioflow_private.owns_shop(a.shop_id) or exists(select 1 from public.jf_memberships m where m.user_id=auth.uid() and m.shop_id=a.shop_id and m.role='admin' and m.status='active') or jioflow_private.can_manage_lower(a.user_id,'logout')) then raise exception 'Device removal is not permitted.' using errcode='42501';end if;
 insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by) values(a.session_id,a.user_id,auth.uid()) on conflict do nothing;
 update public.jf_agent_sessions set status='revoked',removed_at191=coalesce(removed_at191,now()),decided_at=now(),decided_by=auth.uid() where session_id=a.session_id;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),a.user_id,'remove_agent_device',jsonb_build_object('session_id',a.session_id,'shop_id',a.shop_id));
 return jsonb_build_object('message','Device removed. A new login requires approval.');
end $$;
revoke all on function public.jf_remove_agent_device191(uuid) from public,anon;
grant execute on function public.jf_remove_agent_device191(uuid) to authenticated;
create table if not exists jioflow_private.agent_email_changes191(id uuid primary key default gen_random_uuid(),actor_id uuid not null references public.jf_profiles(id),actor_session uuid not null,target_user uuid not null references public.jf_profiles(id),next_email text not null,created_at timestamptz not null default now(),finished_at timestamptz);
alter table jioflow_private.agent_email_changes191 enable row level security;
revoke all on jioflow_private.agent_email_changes191 from public,anon,authenticated;
create or replace function jioflow_private.can_edit_agent_email191(actor uuid,target uuid) returns boolean language sql stable security definer set search_path='' as $$
 select actor<>target and exists(select 1 from public.jf_profiles a where a.id=actor and a.active and a.deleted_at is null) and exists(select 1 from public.jf_profiles p join public.jf_memberships m on m.user_id=p.id join public.jf_shops s on s.id=m.shop_id where p.id=target and p.platform_role is distinct from 'creator' and p.deleted_at is null and m.role='agent' and m.status<>'removed' and s.active and s.archived_at is null and not exists(select 1 from public.jf_shops own where own.owner_id=target) and (s.owner_id=actor or exists(select 1 from public.jf_profiles c where c.id=actor and c.platform_role='creator') or exists(select 1 from public.jf_memberships admin191 where admin191.user_id=actor and admin191.shop_id=m.shop_id and admin191.role='admin' and admin191.status='active' and coalesce((admin191.permissions->>'users')::boolean,false))))
$$;
revoke all on function jioflow_private.can_edit_agent_email191(uuid,uuid) from public,anon,authenticated;
create or replace function public.jf_prepare_agent_email191(target_user uuid,new_email text) returns jsonb language plpgsql security definer set search_path='' as $$
declare rid uuid;mail text:=lower(trim(new_email));begin
 if not coalesce(jioflow_private.session_allowed(),false) or not coalesce(jioflow_private.can_edit_agent_email191(auth.uid(),target_user),false) then raise exception 'Agent email change is not permitted.' using errcode='42501';end if;
 if length(mail)>254 or mail !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Enter a valid login email.' using errcode='22023';end if;
 perform 1 from public.jf_profiles where id=target_user for update;
 if exists(select 1 from auth.users where lower(email)=mail and id<>target_user) or exists(select 1 from public.jf_profiles where lower(email)=mail and id<>target_user) then raise exception 'This login email is already in use.' using errcode='23505';end if;
 insert into jioflow_private.agent_email_changes191(actor_id,actor_session,target_user,next_email) values(auth.uid(),(auth.jwt()->>'session_id')::uuid,target_user,mail) returning id into rid;
 return jsonb_build_object('lease_id',rid,'user_id',target_user,'email',mail);
end $$;
create or replace function public.jf_finish_agent_email191(lease_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare r jioflow_private.agent_email_changes191%rowtype;begin
 select * into r from jioflow_private.agent_email_changes191 where id=lease_id for update;
 if not found or r.created_at<now()-interval '2 minutes' or r.finished_at is not null or not coalesce(jioflow_private.can_edit_agent_email191(r.actor_id,r.target_user),false) or not exists(select 1 from auth.sessions where id=r.actor_session and user_id=r.actor_id) or exists(select 1 from jioflow_private.revoked_sessions where session_id=r.actor_session) then raise exception 'Email change authorization expired.' using errcode='42501';end if;
 perform 1 from public.jf_profiles where id=r.target_user for update;
 if not exists(select 1 from auth.users where id=r.target_user and lower(email)=r.next_email and email_confirmed_at is not null) then raise exception 'Login email update could not be confirmed.';end if;
 update public.jf_profiles set email=r.next_email,pending_email='',managed_agent=true,email_verified_at=null where id=r.target_user;
 insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by) select id,r.target_user,r.actor_id from auth.sessions where user_id=r.target_user on conflict do nothing;
 update public.jf_agent_sessions set status='revoked' where user_id=r.target_user and status in('pending','approved');
 update jioflow_private.agent_email_changes191 set finished_at=now() where id=r.id;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(r.actor_id,r.target_user,'agent_login_email_changed',jsonb_build_object('email',r.next_email));return true;
end $$;
revoke all on function public.jf_prepare_agent_email191(uuid,text),public.jf_finish_agent_email191(uuid) from public,anon,authenticated;
grant execute on function public.jf_prepare_agent_email191(uuid,text) to authenticated;
grant execute on function public.jf_finish_agent_email191(uuid) to service_role;

commit;
