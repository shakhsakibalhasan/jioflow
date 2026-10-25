-- JioFlow CRM foundation. Run AFTER 001_identity_and_shops.sql, once.
-- This prepares storage. It does not enable account creation or CRM writes.
-- No existing browser records are imported or deleted.
begin;

-- Fail before changing anything if the identity migration is absent.
do $$ begin
  if to_regclass('public.jf_profiles') is null or to_regclass('public.jf_memberships') is null
     or to_regprocedure('jioflow_private.is_creator()') is null then
    raise exception 'Run 001_identity_and_shops.sql before this migration.';
  end if;
end $$;

create table public.jf_schema_versions (
  version text primary key,
  applied_at timestamptz not null default now()
);

-- Operational read access is intentionally closed to Agents until server-side
-- approval/device sessions are implemented. Never substitute a browser role check.
create function jioflow_private.reads_operations(target_shop uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select jioflow_private.is_creator() or jioflow_private.owns_shop(target_shop)
    or exists(select 1 from public.jf_memberships m
      join public.jf_profiles p on p.id=m.user_id
      join public.jf_shops s on s.id=m.shop_id
      where m.shop_id=target_shop and m.user_id=(select auth.uid())
        and m.role='admin' and m.status='active'
        and s.active and p.active and p.deleted_at is null);
$$;
create function jioflow_private.reads_finance(target_shop uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select jioflow_private.is_creator() or jioflow_private.owns_shop(target_shop)
    or (jioflow_private.reads_operations(target_shop) and exists(
      select 1 from public.jf_memberships m
      where m.shop_id=target_shop and m.user_id=(select auth.uid())
        and m.role='admin' and m.status='active'
        and m.permissions->'profit'='true'::jsonb));
$$;
revoke all on function jioflow_private.reads_operations(uuid),jioflow_private.reads_finance(uuid) from public,anon,authenticated;
grant execute on function jioflow_private.reads_operations(uuid),jioflow_private.reads_finance(uuid) to authenticated;

-- A customer is unique by normalized phone within a business, not across shops.
create table public.jf_customers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.jf_shops(id) on delete restrict,
  phone text not null check (phone ~ '^\+?[0-9]{7,15}$'),
  full_name text not null default '',
  email text not null default '',
  address text not null default '',
  district text not null default '',
  area text not null default '',
  source text not null default 'manual',
  assigned_membership_id uuid,
  permanent boolean not null default false,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id,id), unique(shop_id,phone),
  check (not permanent or assigned_membership_id is not null)
);
alter table public.jf_memberships add constraint jf_memberships_shop_id_id_key unique(shop_id,id);
alter table public.jf_customers add constraint jf_customer_assigned_same_shop
  foreign key(shop_id,assigned_membership_id) references public.jf_memberships(shop_id,id) on delete restrict;
create index jf_customers_assigned_queue on public.jf_customers(shop_id,assigned_membership_id,updated_at desc,id) where archived_at is null;
create index jf_customers_shop_created on public.jf_customers(shop_id,created_at desc,id);

create table public.jf_products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.jf_shops(id) on delete restrict,
  sku text,
  name text not null check(length(trim(name)) between 1 and 200),
  description text not null default '',
  sale_price numeric(14,2) not null default 0 check(sale_price>=0),
  image_path text,
  active boolean not null default true,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(shop_id,id), unique(shop_id,sku)
);
-- Costs live separately: hiding a UI column never protects financial data.
create table public.jf_product_costs (
  shop_id uuid not null,
  product_id uuid primary key,
  unit_cost numeric(14,2) not null default 0 check(unit_cost>=0),
  updated_at timestamptz not null default now(),
  foreign key(shop_id,product_id) references public.jf_products(shop_id,id) on delete restrict
);
create index jf_products_catalog on public.jf_products(shop_id,active,name,id) where archived_at is null;

create table public.jf_followups (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  customer_id uuid not null,
  status text not null default 'pending' check(status in ('pending','callback','completed','cancelled')),
  call_outcome text check(call_outcome in ('not_attempted','no_answer','busy','not_connected','connected','positive','negative','intermediate')),
  callback_at timestamptz,
  last_contact_at timestamptz,
  updated_by uuid references public.jf_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(shop_id,id), unique(shop_id,customer_id),
  foreign key(shop_id,customer_id) references public.jf_customers(shop_id,id) on delete restrict
);
create index jf_followups_callbacks on public.jf_followups(shop_id,callback_at,id) where status='callback';
create index jf_followups_queue on public.jf_followups(shop_id,status,updated_at desc,id);
create table public.jf_followup_events (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  followup_id uuid not null,
  actor_id uuid references public.jf_profiles(id) on delete restrict,
  outcome text not null,
  note text not null default '',
  callback_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key(shop_id,followup_id) references public.jf_followups(shop_id,id) on delete restrict
);
create index jf_followup_events_history on public.jf_followup_events(shop_id,followup_id,created_at desc,id);

create table public.jf_orders (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  customer_id uuid not null,
  order_number text not null,
  external_order_id text,
  assigned_membership_id uuid,
  entered_by uuid references public.jf_profiles(id) on delete restrict,
  status text not null default 'draft' check(status in ('draft','confirmed','ready_to_book','booked','in_transit','delivered','partial_delivery','returned','cancelled','exchange','replacement')),
  source text not null default 'manual',
  recipient_name text not null,
  recipient_phone text not null check(recipient_phone ~ '^\+?[0-9]{7,15}$'),
  delivery_address text not null default '',
  district text not null default '',
  area text not null default '',
  subtotal numeric(14,2) not null default 0 check(subtotal>=0),
  discount numeric(14,2) not null default 0 check(discount>=0),
  delivery_charge numeric(14,2) not null default 0 check(delivery_charge>=0),
  total numeric(14,2) generated always as (subtotal-discount+delivery_charge) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  confirmed_at timestamptz, completed_at timestamptz,
  unique(shop_id,id), unique(shop_id,order_number), unique(shop_id,external_order_id),
  check(discount<=subtotal),
  foreign key(shop_id,customer_id) references public.jf_customers(shop_id,id) on delete restrict,
  foreign key(shop_id,assigned_membership_id) references public.jf_memberships(shop_id,id) on delete restrict
);
create index jf_orders_list on public.jf_orders(shop_id,created_at desc,id);
create index jf_orders_status on public.jf_orders(shop_id,status,created_at desc,id);
create index jf_orders_agent on public.jf_orders(shop_id,assigned_membership_id,created_at desc,id);
create index jf_orders_customer on public.jf_orders(shop_id,customer_id,created_at desc,id);
create table public.jf_order_items (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  order_id uuid not null,
  product_id uuid,
  product_name text not null,
  variant text not null default '',
  quantity integer not null check(quantity>0),
  unit_price numeric(14,2) not null check(unit_price>=0),
  line_total numeric(16,2) generated always as (quantity*unit_price) stored,
  unique(shop_id,id),
  foreign key(shop_id,order_id) references public.jf_orders(shop_id,id) on delete restrict,
  foreign key(shop_id,product_id) references public.jf_products(shop_id,id) on delete restrict
);
create index jf_order_items_order on public.jf_order_items(shop_id,order_id);
create table public.jf_order_events (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  order_id uuid not null,
  actor_id uuid references public.jf_profiles(id) on delete restrict,
  status text not null,
  note text not null default '',
  created_at timestamptz not null default now(),
  foreign key(shop_id,order_id) references public.jf_orders(shop_id,id) on delete restrict
);
create index jf_order_events_history on public.jf_order_events(shop_id,order_id,created_at desc,id);

create table public.jf_notes (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  customer_id uuid not null,
  order_id uuid,
  body text not null check(length(trim(body)) between 1 and 10000),
  author_id uuid references public.jf_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  foreign key(shop_id,customer_id) references public.jf_customers(shop_id,id) on delete restrict,
  foreign key(shop_id,order_id) references public.jf_orders(shop_id,id) on delete restrict
);
create index jf_notes_customer on public.jf_notes(shop_id,customer_id,created_at desc,id);
create table public.jf_groups (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.jf_shops(id) on delete restrict,
  name text not null check(length(trim(name)) between 1 and 120),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(shop_id,id),unique(shop_id,name)
);
create table public.jf_group_members (
  shop_id uuid not null,
  group_id uuid not null,
  membership_id uuid not null,
  primary key(shop_id,group_id,membership_id),
  foreign key(shop_id,group_id) references public.jf_groups(shop_id,id) on delete restrict,
  foreign key(shop_id,membership_id) references public.jf_memberships(shop_id,id) on delete restrict
);

create table public.jf_payments (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  order_id uuid not null,
  amount numeric(14,2) not null check(amount>0),
  method text not null,
  transaction_id text,
  status text not null default 'pending' check(status in ('pending','verified','rejected','refunded')),
  recorded_by uuid references public.jf_profiles(id) on delete restrict,
  verified_by uuid references public.jf_profiles(id) on delete restrict,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  check(status<>'verified' or (verified_by is not null and verified_at is not null)),
  unique(shop_id,method,transaction_id),
  foreign key(shop_id,order_id) references public.jf_orders(shop_id,id) on delete restrict
);
create index jf_payments_order on public.jf_payments(shop_id,order_id);
create table public.jf_shipments (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  order_id uuid not null,
  courier text not null,
  consignment_id text,
  tracking_code text,
  booking_key uuid not null default gen_random_uuid(),
  status text not null default 'pending' check(status in ('pending','booking','booked','in_transit','delivered','partial_delivery','returned','cancelled','failed')),
  booked_by uuid references public.jf_profiles(id) on delete restrict,
  booked_at timestamptz,
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  unique(shop_id,id), unique(shop_id,courier,consignment_id),unique(booking_key),
  foreign key(shop_id,order_id) references public.jf_orders(shop_id,id) on delete restrict
);
create unique index jf_one_current_shipment on public.jf_shipments(shop_id,order_id) where status not in ('cancelled','failed','returned');
create index jf_shipments_status on public.jf_shipments(shop_id,status,created_at desc,id);
create table public.jf_courier_events (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null,
  shipment_id uuid not null,
  provider_event_id text,
  status text not null,
  occurred_at timestamptz not null default now(),
  received_at timestamptz not null default now(),
  unique(shipment_id,provider_event_id),
  foreign key(shop_id,shipment_id) references public.jf_shipments(shop_id,id) on delete restrict
);
create index jf_courier_events_history on public.jf_courier_events(shop_id,shipment_id,occurred_at desc,id);
-- Immutable cost snapshots and courier settlement amounts are finance-only.
create table public.jf_order_finance (
  shop_id uuid not null,
  order_id uuid primary key,
  product_cost numeric(14,2) not null default 0 check(product_cost>=0),
  courier_charge numeric(14,2) not null default 0 check(courier_charge>=0),
  cod_fee numeric(14,2) not null default 0 check(cod_fee>=0),
  packaging_cost numeric(14,2) not null default 0 check(packaging_cost>=0),
  return_cost numeric(14,2) not null default 0 check(return_cost>=0),
  other_cost numeric(14,2) not null default 0 check(other_cost>=0),
  cod_expected numeric(14,2) not null default 0 check(cod_expected>=0),
  cod_received numeric(14,2) not null default 0 check(cod_received>=0),
  updated_at timestamptz not null default now(),
  foreign key(shop_id,order_id) references public.jf_orders(shop_id,id) on delete restrict
);
create table public.jf_import_jobs (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.jf_shops(id) on delete restrict,
  requested_by uuid references public.jf_profiles(id) on delete restrict,
  file_path text not null,
  file_sha256 text,
  status text not null default 'queued' check(status in ('queued','processing','completed','failed','cancelled')),
  processed_rows integer not null default 0 check(processed_rows>=0),
  inserted_rows integer not null default 0 check(inserted_rows>=0),
  updated_rows integer not null default 0 check(updated_rows>=0),
  rejected_rows integer not null default 0 check(rejected_rows>=0),
  error_report_path text,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);
create index jf_import_jobs_queue on public.jf_import_jobs(shop_id,status,created_at,id);

-- Default deny: no anon access and NO browser writes, even with a valid login.
-- Trusted transaction endpoints will validate permissions and write atomically.
do $$ declare t text; begin
  foreach t in array array['jf_customers','jf_products','jf_product_costs','jf_followups','jf_followup_events','jf_orders','jf_order_items','jf_order_events','jf_notes','jf_groups','jf_group_members','jf_payments','jf_shipments','jf_courier_events','jf_order_finance','jf_import_jobs'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from public,anon,authenticated',t);
    execute format('grant select on public.%I to authenticated',t);
    execute format('grant all on public.%I to service_role',t);
    execute format('create policy %I on public.%I for select to authenticated using (jioflow_private.%I(shop_id))',t||'_read',t,case when t in ('jf_product_costs','jf_order_finance') then 'reads_finance' else 'reads_operations' end);
  end loop;
end $$;
alter table public.jf_schema_versions enable row level security;
revoke all on public.jf_schema_versions from public,anon,authenticated;
grant select on public.jf_schema_versions to authenticated;
grant all on public.jf_schema_versions to service_role;
create policy jf_schema_versions_read on public.jf_schema_versions for select to authenticated using(jioflow_private.is_creator());
insert into public.jf_schema_versions(version) values('001_identity_and_shops'),('002_crm_foundation');
commit;
