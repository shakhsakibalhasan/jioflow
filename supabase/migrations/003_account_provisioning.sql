-- Run once AFTER 002. Creates protected account provisioning RPCs.
begin;

-- Mailbox verification is enforced in database authorization too.
create or replace function jioflow_private.is_creator() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from auth.users where id=(select auth.uid()) and email_confirmed_at is not null) and (exists(select 1 from public.jf_profiles p
    where p.id=(select auth.uid()) and p.platform_role='creator'
      and p.active and p.deleted_at is null));
$$;
create or replace function jioflow_private.owns_shop(target_shop uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from auth.users where id=(select auth.uid()) and email_confirmed_at is not null) and (exists(select 1 from public.jf_shops s join public.jf_profiles p on p.id=s.owner_id
    where s.id=target_shop and s.active and p.id=(select auth.uid())
      and p.active and p.deleted_at is null));
$$;
create or replace function jioflow_private.in_shop(target_shop uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from auth.users where id=(select auth.uid()) and email_confirmed_at is not null) and (jioflow_private.is_creator() or jioflow_private.owns_shop(target_shop)
    or exists(select 1 from public.jf_memberships m
      join public.jf_profiles p on p.id=m.user_id
      join public.jf_shops s on s.id=m.shop_id
      where m.shop_id=target_shop and m.user_id=(select auth.uid())
        and m.status='active' and s.active and p.active and p.deleted_at is null));
$$;
create or replace function jioflow_private.manages_shop(target_shop uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from auth.users where id=(select auth.uid()) and email_confirmed_at is not null) and (jioflow_private.is_creator() or jioflow_private.owns_shop(target_shop)
    or exists(select 1 from public.jf_memberships m
      join public.jf_profiles p on p.id=m.user_id
      join public.jf_shops s on s.id=m.shop_id
      where m.shop_id=target_shop and m.user_id=(select auth.uid())
        and m.status='active' and m.role='admin' and m.permissions->'users'='true'::jsonb
        and s.active and p.active and p.deleted_at is null));
$$;

create or replace function jioflow_private.reads_operations(target_shop uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from auth.users where id=(select auth.uid()) and email_confirmed_at is not null) and (jioflow_private.is_creator() or jioflow_private.owns_shop(target_shop)
    or exists(select 1 from public.jf_memberships m
      join public.jf_profiles p on p.id=m.user_id
      join public.jf_shops s on s.id=m.shop_id
      where m.shop_id=target_shop and m.user_id=(select auth.uid())
        and m.role='admin' and m.status='active'
        and s.active and p.active and p.deleted_at is null));
$$;
alter table public.jf_profiles add column email_verified_at timestamptz;
update public.jf_profiles p set email_verified_at=u.email_confirmed_at from auth.users u where u.id=p.id;
create function jioflow_private.sync_verified_email() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 update public.jf_profiles set email_verified_at=new.email_confirmed_at where id=new.id;
 return new;
end $$;
revoke all on function jioflow_private.sync_verified_email() from public,anon,authenticated;
create trigger jf_sync_verified_email after update of email_confirmed_at on auth.users
 for each row execute function jioflow_private.sync_verified_email();

create unique index jf_profile_email_unique on public.jf_profiles(lower(email));
create table public.jf_account_requests (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.jf_profiles(id),
  shop_id uuid not null references public.jf_shops(id),
  account_role text not null check(account_role in ('owner','admin','agent')),
  full_name text not null check(length(trim(full_name)) between 1 and 120),
  email text not null,
  phone text not null default '',
  user_id uuid references public.jf_profiles(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create index jf_account_requests_actor_time on public.jf_account_requests(actor_id,created_at desc);
alter table public.jf_account_requests enable row level security;
revoke all on public.jf_account_requests from public,anon,authenticated;
grant all on public.jf_account_requests to service_role;

create function jioflow_private.can_provision(sid uuid, desired_role text) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from auth.users u join public.jf_profiles p on p.id=u.id
   where u.id=(select auth.uid()) and u.email_confirmed_at is not null
     and p.active and p.deleted_at is null)
 and exists(select 1 from public.jf_shops s where s.id=sid and s.active)
 and case desired_role
   when 'owner' then jioflow_private.is_creator()
   when 'admin' then jioflow_private.is_creator() or jioflow_private.owns_shop(sid)
   when 'agent' then jioflow_private.manages_shop(sid)
   else false end;
$$;
revoke all on function jioflow_private.can_provision(uuid,text) from public,anon,authenticated;

create function public.jf_create_shop(shop_name text, contact_email text default '', contact_phone text default '', shop_address text default '', shop_website text default '') returns uuid
language plpgsql security definer set search_path = '' as $$
declare sid uuid;
begin
 if not jioflow_private.is_creator() or not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then raise exception 'Creator access required.' using errcode='42501'; end if;
 if length(trim(shop_name)) not between 1 and 120 then raise exception 'Enter a shop name.' using errcode='22023'; end if;
 insert into public.jf_shops(name,email,phone,address,website,created_by)
 values(trim(shop_name),left(trim(contact_email),254),left(trim(contact_phone),30),left(shop_address,1000),left(shop_website,500),auth.uid()) returning id into sid;
 return sid;
end $$;

-- A short-lived server-checked request binds the role/shop/email before sending mail.
-- Per-minute throttling prevents repeated invite clicks from flooding mail delivery.
create function public.jf_prepare_invitation(target_shop uuid, desired_role text, person_name text, person_email text, person_phone text default '') returns uuid
language plpgsql security definer set search_path = '' as $$
declare rid uuid; normalized_email text := lower(trim(person_email));
begin
 perform 1 from public.jf_profiles where id=auth.uid() for update;
 if not jioflow_private.can_provision(target_shop,desired_role) then raise exception 'Account creation is not permitted.' using errcode='42501'; end if;
 if length(trim(person_name)) not between 1 and 120 or length(normalized_email)>254 or normalized_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Enter a valid name and email.' using errcode='22023'; end if;
 if exists(select 1 from public.jf_profiles where lower(email)=normalized_email) then raise exception 'This email already has an account.' using errcode='23505'; end if;
 if desired_role='owner' and exists(select 1 from public.jf_shops where id=target_shop and owner_id is not null) then raise exception 'This shop already has an Owner.' using errcode='23505'; end if;
 if (select count(*) from public.jf_account_requests where actor_id=auth.uid() and created_at>now()-interval '1 minute')>=10 then raise exception 'Please wait a minute before sending more invitations.' using errcode='P0001'; end if;
 insert into public.jf_account_requests(actor_id,shop_id,account_role,full_name,email,phone)
 values(auth.uid(),target_shop,desired_role,trim(person_name),normalized_email,left(trim(person_phone),30)) returning id into rid;
 return rid;
end $$;

create function public.jf_finish_invitation(request_id uuid, invited_user uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare r public.jf_account_requests%rowtype; auth_email text;
begin
 select * into r from public.jf_account_requests where id=request_id and actor_id=auth.uid() for update;
 if not found then raise exception 'Invitation request not found.' using errcode='42501'; end if;
 if r.completed_at is not null then
   if r.user_id=invited_user then return invited_user; end if;
   raise exception 'Invitation already completed.' using errcode='23505';
 end if;
 if r.created_at<now()-interval '15 minutes' or not jioflow_private.can_provision(r.shop_id,r.account_role) then raise exception 'Invitation expired or access changed.' using errcode='42501'; end if;
 perform 1 from public.jf_shops where id=r.shop_id for update;
 select lower(email) into auth_email from auth.users where id=invited_user and invited_at is not null;
 if auth_email is distinct from r.email then raise exception 'Invited identity does not match.' using errcode='42501'; end if;
 if exists(select 1 from public.jf_profiles where id=invited_user or lower(email)=r.email) then raise exception 'This identity already has an account.' using errcode='23505'; end if;
 if r.account_role='owner' and exists(select 1 from public.jf_shops where id=r.shop_id and owner_id is not null) then raise exception 'This shop already has an Owner.' using errcode='23505'; end if;
 insert into public.jf_profiles(id,full_name,email,phone,email_verified_at) select invited_user,r.full_name,r.email,r.phone,u.email_confirmed_at from auth.users u where u.id=invited_user;
 if r.account_role='owner' then update public.jf_shops set owner_id=invited_user where id=r.shop_id;
 else
   insert into public.jf_memberships(shop_id,user_id,role,status,permissions)
   values(r.shop_id,invited_user,r.account_role,case when r.account_role='agent' then 'pending' else 'active' end,
     case when r.account_role='admin' then '{"users":true,"assign":true,"booking":true,"import":true,"settings":true}'::jsonb else '{}'::jsonb end);
 end if;
 update public.jf_account_requests set user_id=invited_user,completed_at=now() where id=r.id;
 return invited_user;
end $$;

revoke all on function public.jf_create_shop(text,text,text,text,text),public.jf_prepare_invitation(uuid,text,text,text,text),public.jf_finish_invitation(uuid,uuid) from public,anon,authenticated;
grant execute on function public.jf_create_shop(text,text,text,text,text),public.jf_prepare_invitation(uuid,text,text,text,text),public.jf_finish_invitation(uuid,uuid) to authenticated;

-- Admins can see the assigned Owner's basic profile without managing the Owner.
create or replace function jioflow_private.can_read_profile(target_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select jioflow_private.is_creator()
 or (target_user=(select auth.uid()) and exists(select 1 from public.jf_profiles p where p.id=(select auth.uid()) and p.active and p.deleted_at is null))
 or exists(select 1 from public.jf_memberships m where m.user_id=target_user and jioflow_private.manages_shop(m.shop_id))
 or exists(select 1 from public.jf_shops s where s.owner_id=target_user and jioflow_private.reads_operations(s.id));
$$;
insert into public.jf_schema_versions(version) values('003_account_provisioning');
commit;
