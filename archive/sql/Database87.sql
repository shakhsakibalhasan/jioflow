begin;
create table if not exists public.jf_history_connections87(shop_id uuid primary key references public.jf_shops(id) on delete cascade,config jsonb not null,sealed text not null,updated_at timestamptz not null default now());
alter table public.jf_history_connections87 enable row level security;
revoke all on public.jf_history_connections87 from public,anon,authenticated;
grant select,insert,update,delete on public.jf_history_connections87 to service_role;
commit;
