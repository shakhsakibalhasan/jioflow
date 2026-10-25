-- JioFlow: first backend migration. Run once in Supabase SQL Editor.
-- This creates protected identity/shop tables; it does not migrate browser accounts.
-- No passwords or service-role keys belong in this file.
begin;
create schema if not exists jioflow_private;
revoke all on schema jioflow_private from public, anon, authenticated;

create table public.jf_profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  full_name text not null check (length(trim(full_name)) between 1 and 120),
  email text not null,
  phone text not null default '',
  avatar_path text,
  platform_role text check (platform_role is null or platform_role = 'creator'),
  active boolean not null default true,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index jf_single_creator on public.jf_profiles(platform_role)
  where platform_role = 'creator';

create table public.jf_shops (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 120),
  owner_id uuid unique references public.jf_profiles(id) on delete restrict,
  email text not null default '',
  phone text not null default '',
  logo_path text,
  address text not null default '',
  website text not null default '',
  active boolean not null default true,
  created_by uuid references public.jf_profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.jf_memberships (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.jf_shops(id) on delete restrict,
  user_id uuid not null references public.jf_profiles(id) on delete restrict,
  role text not null check (role in ('admin','agent')),
  permissions jsonb not null default '{}'::jsonb check (jsonb_typeof(permissions) = 'object'),
  status text not null default 'pending' check (status in ('pending','active','disabled','removed')),
  created_at timestamptz not null default now(),
  unique (shop_id, user_id),
  unique (user_id)
);
create index jf_memberships_shop_status on public.jf_memberships(shop_id,status);

-- SECURITY DEFINER helpers query tables without recursively invoking their policies.
-- They expose only caller-relative booleans and never accept a caller-provided user id.
create function jioflow_private.is_creator() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.jf_profiles p
    where p.id=(select auth.uid()) and p.platform_role='creator'
      and p.active and p.deleted_at is null);
$$;
create function jioflow_private.owns_shop(target_shop uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.jf_shops s join public.jf_profiles p on p.id=s.owner_id
    where s.id=target_shop and s.active and p.id=(select auth.uid())
      and p.active and p.deleted_at is null);
$$;
create function jioflow_private.in_shop(target_shop uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select jioflow_private.is_creator() or jioflow_private.owns_shop(target_shop)
    or exists(select 1 from public.jf_memberships m
      join public.jf_profiles p on p.id=m.user_id
      join public.jf_shops s on s.id=m.shop_id
      where m.shop_id=target_shop and m.user_id=(select auth.uid())
        and m.status='active' and s.active and p.active and p.deleted_at is null);
$$;
create function jioflow_private.manages_shop(target_shop uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select jioflow_private.is_creator() or jioflow_private.owns_shop(target_shop)
    or exists(select 1 from public.jf_memberships m
      join public.jf_profiles p on p.id=m.user_id
      join public.jf_shops s on s.id=m.shop_id
      where m.shop_id=target_shop and m.user_id=(select auth.uid())
        and m.status='active' and m.role='admin' and m.permissions->'users'='true'::jsonb
        and s.active and p.active and p.deleted_at is null);
$$;
create function jioflow_private.can_read_profile(target_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select jioflow_private.is_creator()
    or (target_user=(select auth.uid()) and exists(select 1 from public.jf_profiles p
      where p.id=(select auth.uid()) and p.active and p.deleted_at is null))
    or exists(select 1 from public.jf_memberships m
      where m.user_id=target_user and jioflow_private.manages_shop(m.shop_id));
$$;
revoke all on function jioflow_private.is_creator(), jioflow_private.owns_shop(uuid), jioflow_private.in_shop(uuid), jioflow_private.manages_shop(uuid), jioflow_private.can_read_profile(uuid) from public, anon, authenticated;
grant usage on schema jioflow_private to authenticated;
grant execute on function jioflow_private.is_creator(), jioflow_private.owns_shop(uuid), jioflow_private.in_shop(uuid), jioflow_private.manages_shop(uuid), jioflow_private.can_read_profile(uuid) to authenticated;

alter table public.jf_profiles enable row level security;
alter table public.jf_shops enable row level security;
alter table public.jf_memberships enable row level security;
revoke all on public.jf_profiles,public.jf_shops,public.jf_memberships from anon,authenticated;
grant select on public.jf_profiles,public.jf_shops,public.jf_memberships to authenticated;
grant all on public.jf_profiles,public.jf_shops,public.jf_memberships to service_role;
create policy jf_profiles_read on public.jf_profiles for select to authenticated
  using (jioflow_private.can_read_profile(id));
create policy jf_shops_read on public.jf_shops for select to authenticated
  using (jioflow_private.in_shop(id));
create policy jf_memberships_read on public.jf_memberships for select to authenticated
  using (jioflow_private.manages_shop(shop_id)
    or (user_id=(select auth.uid()) and jioflow_private.in_shop(shop_id)));

-- Profile creation and role/permission changes remain privileged operations.
-- Intentionally no client INSERT/UPDATE/DELETE grants: signup metadata cannot
-- turn somebody into Creator/Owner/Admin. Provisioning endpoints come next.
comment on table public.jf_profiles is 'JioFlow account identity. Roles are assigned by trusted provisioning, never signup metadata.';
comment on table public.jf_shops is 'Independent businesses. Only Creator will provision shops and Owners.';
comment on table public.jf_memberships is 'Shop-scoped Admin/Agent accounts. Owner is defined only by jf_shops.owner_id.';
commit;
