-- Run in your existing Supabase project's SQL editor after reviewing.
create table if not exists public.jf_steadfast_bookings (
  invoice text primary key,
  created_by uuid not null,
  state text not null check(state in ('requesting','booked','needs_reconciliation')),
  consignment_id text unique,
  tracking_code text,
  delivery_status text,
  created_at timestamptz not null default now()
);
create table if not exists public.jf_steadfast_events (
  id bigint generated always as identity primary key,
  invoice text,
  consignment_id text,
  delivery_status text not null,
  received_at timestamptz not null default now()
);
create index if not exists jf_steadfast_events_invoice_received
on public.jf_steadfast_events(invoice,received_at desc);
alter table public.jf_steadfast_bookings enable row level security;
alter table public.jf_steadfast_events enable row level security;
revoke all on public.jf_steadfast_bookings from anon, authenticated;
revoke all on public.jf_steadfast_events from anon, authenticated;
-- Service role bypasses RLS. No frontend direct access is granted.
