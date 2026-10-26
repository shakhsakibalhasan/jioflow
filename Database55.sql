begin;
create table if not exists public.jf_manual_couriers(id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.jf_shops(id) on delete cascade,name text not null check(length(name) between 1 and 100),courier_type text not null check(length(courier_type) between 1 and 80),active boolean not null default true,logo_path text not null default '' check(length(logo_path)<=360000),default_note text not null default '' check(length(default_note)<=480),deleted_at timestamptz,updated_at timestamptz not null default now());
alter table public.jf_manual_couriers add column if not exists logo_path text not null default '' check(length(logo_path)<=360000);
alter table public.jf_manual_couriers enable row level security;
revoke all on public.jf_manual_couriers from public,anon,authenticated;
create or replace function public.jf_manual_delivery_methods(target_shop uuid,operation text default 'list',method_id uuid default null,details jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare configure boolean;rid uuid;
begin
 if not jioflow_private.session_allowed() or not jioflow_private.reads_operations(target_shop) or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null) then raise exception 'Courier access denied.' using errcode='42501';end if;
 configure:=coalesce(jioflow_private.has_permission(target_shop,'integration'),false);
 if operation<>'list' and not configure then raise exception 'Courier configuration permission required.' using errcode='42501';end if;
 if operation='save' then
  if length(trim(coalesce(details->>'name',''))) not between 1 and 100 or length(trim(coalesce(details->>'courier_type',''))) not between 1 and 80 or length(coalesce(details->>'default_note',''))>480 or length(coalesce(details->>'logo_path',''))>360000 then raise exception 'Check the courier name and type.';end if;
  if method_id is null then insert into public.jf_manual_couriers(shop_id,name,courier_type,active,logo_path,default_note) values(target_shop,trim(details->>'name'),trim(details->>'courier_type'),coalesce((details->>'active')::boolean,true),coalesce(details->>'logo_path',''),coalesce(details->>'default_note','')) returning id into rid;
  else update public.jf_manual_couriers set name=trim(details->>'name'),courier_type=trim(details->>'courier_type'),active=coalesce((details->>'active')::boolean,true),logo_path=coalesce(details->>'logo_path',logo_path),default_note=coalesce(details->>'default_note',''),updated_at=now() where id=method_id and shop_id=target_shop and deleted_at is null returning id into rid;if rid is null then raise exception 'Courier not found.';end if;end if;
 elsif operation='remove' then update public.jf_manual_couriers set active=false,deleted_at=now(),updated_at=now() where id=method_id and shop_id=target_shop and deleted_at is null returning id into rid;if rid is null then raise exception 'Courier not found.';end if;
 elsif operation<>'list' then raise exception 'Unsupported courier action.';end if;
 return jsonb_build_object('can_configure',configure,'methods',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'name',m.name,'courier_type',m.courier_type,'logo_path',m.logo_path,'provider','manual','kind','manual','active',m.active,'preferred',false,'booking_enabled',false,'default_note',m.default_note) order by m.name) from public.jf_manual_couriers m where m.shop_id=target_shop and m.deleted_at is null and (configure or m.active)),'[]'::jsonb));
end $$;
revoke all on function public.jf_manual_delivery_methods(uuid,text,uuid,jsonb) from public,anon;
grant execute on function public.jf_manual_delivery_methods(uuid,text,uuid,jsonb) to authenticated;
create index if not exists jf_manual_couriers_shop on public.jf_manual_couriers(shop_id) where deleted_at is null;
insert into public.jf_schema_versions(version) values('036_manual_couriers') on conflict do nothing;
commit;
