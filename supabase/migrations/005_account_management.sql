-- Run once after 004. Creator account management and JioFlow session revocation.
begin;
do $$ begin
 if not exists(select 1 from public.jf_schema_versions where version='004_products_customers_followups') then raise exception 'Apply migration 004 first.'; end if;
end $$;
create table jioflow_private.revoked_sessions (
 session_id uuid primary key, user_id uuid not null references public.jf_profiles(id),
 revoked_by uuid not null references public.jf_profiles(id), revoked_at timestamptz not null default now()
);
create index jf_revoked_sessions_user on jioflow_private.revoked_sessions(user_id);
create table jioflow_private.account_audit (
 id uuid primary key default gen_random_uuid(), actor_id uuid not null references public.jf_profiles(id),
 target_id uuid not null references public.jf_profiles(id), action text not null,
 details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
alter table jioflow_private.revoked_sessions enable row level security;
alter table jioflow_private.account_audit enable row level security;
revoke all on jioflow_private.revoked_sessions,jioflow_private.account_audit from public,anon,authenticated;

-- A refresh keeps the same session_id, so refreshing cannot undo a force logout.
-- Auth tables are read only here. No Auth sessions or identities are deleted.
create function jioflow_private.session_allowed() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.users u join public.jf_profiles p on p.id=u.id
  where u.id=auth.uid() and u.email_confirmed_at is not null and p.active and p.deleted_at is null)
 and exists(select 1 from auth.sessions s where s.user_id=auth.uid() and s.id::text=auth.jwt()->>'session_id')
 and not exists(select 1 from jioflow_private.revoked_sessions r where r.user_id=auth.uid() and r.session_id::text=auth.jwt()->>'session_id');
$$;
revoke all on function jioflow_private.session_allowed() from public,anon,authenticated;

-- Preserve helper signatures and grants; add the gate to every authorization path,
-- including self-profile reads and operational/finance permissions.
do $$
declare f record; body text;
begin
 for f in select p.oid,p.proname,p.prosrc,pg_get_function_identity_arguments(p.oid) args
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='jioflow_private' and p.proname in
   ('is_creator','owns_shop','in_shop','manages_shop','can_read_profile','reads_operations','reads_finance','has_permission','can_provision')
 loop
  body:=regexp_replace(trim(f.prosrc),';[[:space:]]*$','');
  execute format('create or replace function jioflow_private.%I(%s) returns boolean language sql stable security definer set search_path = '''' as %L',f.proname,f.args,'select jioflow_private.session_allowed() and ('||body||')');
 end loop;
end $$;

create function public.jf_session_status() returns boolean
language sql stable security definer set search_path='' as $$select jioflow_private.session_allowed()$$;

create function public.jf_manage_account(target_user uuid,account_action text,details jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare target public.jf_profiles%rowtype; session_count integer:=0; person_name text; person_phone text;
begin
 if not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501'; end if;
 if target_user=auth.uid() then raise exception 'You cannot manage your own Creator account here.' using errcode='42501'; end if;
 select * into target from public.jf_profiles where id=target_user for update;
 if not found or target.deleted_at is not null or target.platform_role='creator' then raise exception 'This account cannot be managed.' using errcode='42501'; end if;
 if account_action not in ('edit','force_logout','remove') then raise exception 'Unsupported account action.' using errcode='22023'; end if;
 if account_action='edit' then
  if jsonb_typeof(details) is distinct from 'object' or exists(select 1 from jsonb_object_keys(details) k where k not in ('full_name','phone')) then raise exception 'Only name and phone can be edited here.' using errcode='22023'; end if;
  person_name:=trim(coalesce(details->>'full_name',target.full_name));person_phone:=trim(coalesce(details->>'phone',target.phone));
  if length(person_name) not between 1 and 120 or length(person_phone)>30 then raise exception 'Enter a valid name and phone.' using errcode='22023'; end if;
  update public.jf_profiles set full_name=person_name,phone=person_phone where id=target_user;
  insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),target_user,'edit',jsonb_build_object('before_name',target.full_name,'after_name',person_name,'before_phone',target.phone,'after_phone',person_phone));
  return jsonb_build_object('message','Account details saved.');
 end if;
 insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by)
  select s.id,target_user,auth.uid() from auth.sessions s where s.user_id=target_user
  on conflict(session_id) do nothing;
 get diagnostics session_count=row_count;
 if account_action='remove' then
  -- Clear permanent ownership and assignments together, preserving all history.
  update public.jf_customers set assigned_membership_id=null,permanent=false
   where assigned_membership_id in(select id from public.jf_memberships where user_id=target_user);
  delete from public.jf_group_members where membership_id in(select id from public.jf_memberships where user_id=target_user);
  update public.jf_memberships set status='removed' where user_id=target_user;
  update public.jf_shops set owner_id=null where owner_id=target_user;
  update public.jf_profiles set active=false,deleted_at=now() where id=target_user;
 end if;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),target_user,account_action,jsonb_build_object('revoked_sessions',session_count));
 return jsonb_build_object('revoked_sessions',session_count,'message',case when account_action='remove' then 'Account removed. Login disabled; customer and order history preserved.' else 'Existing JioFlow sessions revoked. The user can sign in again.' end);
end $$;
revoke all on function public.jf_manage_account(uuid,text,jsonb),public.jf_session_status() from public,anon,authenticated;
grant execute on function public.jf_manage_account(uuid,text,jsonb),public.jf_session_status() to authenticated;
insert into public.jf_schema_versions(version) values('005_account_management');
commit;
