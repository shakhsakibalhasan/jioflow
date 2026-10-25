-- In-app delivery methods. Apply after 025. No plaintext API credentials.
begin;
do $$begin if not exists(select 1 from public.jf_schema_versions where version='025_steadfast_integration') then raise exception 'Apply database update 025 first.';end if;end$$;
create table public.jf_courier_methods (
 id uuid primary key default gen_random_uuid(), shop_id uuid not null references public.jf_shops(id) on delete cascade,
 provider text not null check(provider='steadfast'), name text not null check(length(name) between 1 and 100),
 sealed text not null, active boolean not null default true, preferred boolean not null default false,
 booking_enabled boolean not null default false, default_note text not null default '' check(length(default_note)<=480),
 send_product_names boolean not null default false, deleted_at timestamptz,
 checked_at timestamptz, check_status text, updated_at timestamptz not null default now(),
 unique(shop_id,id)
);
create unique index jf_courier_preferred on public.jf_courier_methods(shop_id) where preferred and active and deleted_at is null;
alter table public.jf_courier_methods enable row level security;
revoke all on public.jf_courier_methods from public,anon,authenticated;
alter table public.jf_shipments add column method_id uuid;
alter table public.jf_shipments add constraint jf_shipment_method foreign key(shop_id,method_id) references public.jf_courier_methods(shop_id,id);
alter table public.jf_orders add column preferred_method_id uuid;
alter table public.jf_orders add constraint jf_order_delivery_method foreign key(shop_id,preferred_method_id) references public.jf_courier_methods(shop_id,id);
alter function public.jf_courier_access(uuid,uuid) rename to jf_courier_access_before_methods;
revoke all on function public.jf_courier_access_before_methods(uuid,uuid) from public,anon,authenticated;
create function public.jf_courier_access(target_shop uuid,target_order uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 result:=public.jf_courier_access_before_methods(target_shop,target_order);
 if target_order is not null then result:=result||jsonb_build_object('order',(result->'order')||jsonb_build_object('preferred_method_id',(select preferred_method_id from public.jf_orders where shop_id=target_shop and id=target_order)));end if;
 return result;
end $$;
alter function public.jf_save_order(uuid,uuid,jsonb) rename to jf_save_order_before_methods;
revoke all on function public.jf_save_order_before_methods(uuid,uuid,jsonb) from public,anon,authenticated;
create function public.jf_save_order(target_shop uuid,request_id uuid,details jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare oid uuid; mid uuid;
begin
 if not jioflow_private.has_permission(target_shop,'assign') then raise exception 'Order access denied.' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(target_shop::text||request_id::text,0));
 if exists(select 1 from public.jf_orders where shop_id=target_shop and request_key=request_id) then return public.jf_save_order_before_methods(target_shop,request_id,details-'method_id');end if;
 mid:=nullif(details->>'method_id','')::uuid;
 if mid is not null and not exists(select 1 from public.jf_courier_methods where shop_id=target_shop and id=mid and active and deleted_at is null) then raise exception 'Choose an active courier method.';end if;
 oid:=public.jf_save_order_before_methods(target_shop,request_id,details-'method_id');
 update public.jf_orders set preferred_method_id=mid where id=oid and shop_id=target_shop;
 return oid;
end $$;
create function public.jf_delivery_methods(target_shop uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare a jsonb; result jsonb;
begin
 a:=public.jf_courier_access(target_shop,null);
 select coalesce(jsonb_agg(to_jsonb(m)-'sealed' order by preferred desc,name),'[]') into result from public.jf_courier_methods m where shop_id=target_shop and deleted_at is null and (a->>'can_configure'='true' or active);
 return jsonb_build_object('can_configure',a->'can_configure','methods',result,'has_methods',exists(select 1 from public.jf_courier_methods where shop_id=target_shop));
end $$;
create function public.jf_delivery_method_save(target_shop uuid,method_id uuid,details jsonb,encrypted_keys text default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare a jsonb; m public.jf_courier_methods; rid uuid; use_active boolean; use_default boolean;
begin
 a:=public.jf_courier_access(target_shop,null);
 if a->>'can_configure'<>'true' or jioflow_private.agent_member(target_shop) is not null then raise exception 'Integration permission required.' using errcode='42501';end if;
 perform 1 from public.jf_shops where id=target_shop for update;
 if jsonb_typeof(details)<>'object' or exists(select 1 from jsonb_object_keys(details) k where k not in('name','provider','active','preferred','booking_enabled','default_note','send_product_names')) or length(trim(coalesce(details->>'name',''))) not between 1 and 100 or coalesce(details->>'provider','')<>'steadfast' or length(coalesce(details->>'default_note',''))>480 then raise exception 'Check the courier details.';end if;
 if exists(select 1 from jsonb_each(details) p where p.key in('active','preferred','booking_enabled','send_product_names') and jsonb_typeof(p.value)<>'boolean') then raise exception 'Check the courier switches.';end if;
 if method_id is not null then select * into m from public.jf_courier_methods where id=method_id and shop_id=target_shop and deleted_at is null for update;if m.id is null and (encrypted_keys is null or exists(select 1 from public.jf_courier_methods where id=method_id)) then raise exception 'Courier method unavailable.';end if;end if;
 if encrypted_keys is not null and (length(encrypted_keys) not between 40 and 6000 or encrypted_keys !~ '^v1[.]') then raise exception 'Invalid encrypted credentials.';end if;
 if m.id is null and encrypted_keys is null then raise exception 'Enter both API keys.';end if;
 if m.id is not null and encrypted_keys is not null and exists(select 1 from public.jf_shipments where shop_id=target_shop and jf_shipments.method_id=m.id and status not in('delivered','partial_delivery','cancelled','returned','failed')) then raise exception 'This method has open shipments. Add a new method to change its credentials.';end if;
 use_active:=coalesce((details->>'active')::boolean,true);use_default:=use_active and coalesce((details->>'preferred')::boolean,false);
 if use_default then update public.jf_courier_methods set preferred=false where shop_id=target_shop and preferred;end if;
 rid:=coalesce(m.id,method_id,gen_random_uuid());
 insert into public.jf_courier_methods(id,shop_id,provider,name,sealed,active,preferred,booking_enabled,default_note,send_product_names)
 values(rid,target_shop,'steadfast',trim(details->>'name'),coalesce(encrypted_keys,m.sealed),use_active,use_default,coalesce((details->>'booking_enabled')::boolean,false),coalesce(details->>'default_note',''),coalesce((details->>'send_product_names')::boolean,false))
 on conflict(id) do update set name=excluded.name,sealed=excluded.sealed,active=excluded.active,preferred=excluded.preferred,booking_enabled=excluded.booking_enabled,default_note=excluded.default_note,send_product_names=excluded.send_product_names,updated_at=now(),checked_at=case when encrypted_keys is null then jf_courier_methods.checked_at else null end,check_status=case when encrypted_keys is null then jf_courier_methods.check_status else null end where jf_courier_methods.shop_id=target_shop and jf_courier_methods.deleted_at is null;
 return rid;
end $$;
create function public.jf_delivery_method_remove(target_shop uuid,method_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare a jsonb;
begin
 a:=public.jf_courier_access(target_shop,null);
 if a->>'can_configure'<>'true' or jioflow_private.agent_member(target_shop) is not null then raise exception 'Integration permission required.' using errcode='42501';end if;
 update public.jf_courier_methods set active=false,preferred=false,booking_enabled=false,deleted_at=now() where shop_id=target_shop and id=method_id and deleted_at is null;
 return found;
end $$;
-- Encrypted material is returned only to the backend service role.
create function public.jf_delivery_method_secrets(target_shop uuid,target_method uuid default null) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(m)),'[]') from public.jf_courier_methods m where shop_id=target_shop and (target_method is null or id=target_method);
$$;
create function public.jf_delivery_method_checked(target_shop uuid,target_method uuid,result text) returns boolean
language sql security definer set search_path='' as $$
 update public.jf_courier_methods set checked_at=now(),check_status=case when result='verified' then 'verified' else 'failed' end where shop_id=target_shop and id=target_method and deleted_at is null returning true;
$$;
create function public.jf_courier_reserve(target_shop uuid,target_order uuid,target_method uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.jf_courier_methods; s public.jf_shipments; result jsonb; description text;
begin
 perform public.jf_courier_access(target_shop,target_order);
 select * into m from public.jf_courier_methods where id=target_method and shop_id=target_shop and active and deleted_at is null and booking_enabled;
 if m.id is null then raise exception 'Choose an active courier with booking enabled.';end if;
 perform 1 from public.jf_orders where id=target_order and shop_id=target_shop for update;
 select * into s from public.jf_shipments where shop_id=target_shop and order_id=target_order order by created_at desc limit 1;
 if s.id is not null and s.method_id is distinct from target_method then raise exception 'This order already uses another delivery method.';end if;
 result:=public.jf_courier_reserve(target_shop,target_order);
 if result->>'already_booked'='true' then return result;end if;
 if m.send_product_names then select left(string_agg(product_name||' x '||quantity::text,', ' order by id),255) into description from public.jf_order_items where shop_id=target_shop and order_id=target_order;end if;
 update public.jf_shipments set method_id=target_method,request_payload=request_payload||jsonb_build_object('note',case when coalesce(request_payload->>'note','')='' then m.default_note else request_payload->>'note' end)||case when description is not null then jsonb_build_object('item_description',description) else '{}'::jsonb end where id=(result->>'shipment_id')::uuid returning request_payload into result;
 return jsonb_build_object('already_booked',false,'shipment_id',s.id,'payload',result)||jsonb_build_object('shipment_id',(select id from public.jf_shipments where shop_id=target_shop and order_id=target_order order by created_at desc limit 1));
end $$;
create function public.jf_phone_own_record(target_shop uuid,phone text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare normalized text; result jsonb;
begin
 perform public.jf_courier_access(target_shop,null);normalized:=jioflow_private.normalize_phone(phone);
 with live as materialized(select id,order_number,recipient_name,recipient_phone,delivery_address,status,total,created_at from public.jf_orders where shop_id=target_shop and recipient_phone=normalized and archived_at is null and jioflow_private.can_read_order(shop_id,id)),
 history as(select h.id,h.external_id order_number,c.full_name recipient_name,c.phone recipient_phone,c.address delivery_address,lower(replace(coalesce(h.details->>'status','imported'),' ','_')) status,case when coalesce(h.details->>'total','') ~ '^[0-9]+([.][0-9]+)?$' then (h.details->>'total')::numeric else 0 end total,h.updated_at created_at from public.jf_order_history h join public.jf_customers c on c.shop_id=h.shop_id and c.id=h.customer_id where h.shop_id=target_shop and c.phone=normalized and c.archived_at is null and jioflow_private.can_read_customer(c.shop_id,c.id) and not exists(select 1 from live l where l.order_number=h.external_id)),
 records as(select * from live union all select * from history)
 select jsonb_build_object('total',count(*),'delivered',count(*) filter(where status in('delivered','completed','complete')),'cancelled',count(*) filter(where status in('cancelled','canceled')),'returned',count(*) filter(where status='returned'),'rows',coalesce((select jsonb_agg(to_jsonb(r)) from(select * from records order by created_at desc limit 25)r),'[]'::jsonb),'customer',(select jsonb_build_object('full_name',c.full_name,'phone',c.phone,'address',c.address) from public.jf_customers c where c.shop_id=target_shop and c.phone=normalized and c.archived_at is null and jioflow_private.can_read_customer(c.shop_id,c.id) limit 1)) into result from records;
 return result;
end $$;
-- Include each shipment's saved method when polling, including inactive/removed
-- methods so existing parcels continue to be tracked with the correct credentials.
create or replace function public.jf_courier_poll_claim(batch_size integer default 20) returns jsonb
language sql security definer set search_path='' as $$
 with due as (select s.id from public.jf_shipments s join public.jf_shops b on b.id=s.shop_id where s.courier='steadfast' and s.consignment_id is not null and s.status not in ('delivered','partial_delivery','cancelled','returned','failed') and b.active and b.archived_at is null and (s.poll_lease_until is null or s.poll_lease_until<now()) and (s.last_checked_at is null or s.last_checked_at<now()-interval '25 minutes') order by s.last_checked_at nulls first,s.created_at limit least(greatest(batch_size,1),20) for update of s skip locked), claimed as(update public.jf_shipments s set poll_lease_until=now()+interval '90 seconds' from due where s.id=due.id returning s.id,s.shop_id,s.consignment_id,s.method_id) select coalesce(jsonb_agg(to_jsonb(claimed)),'[]'::jsonb) from claimed;
$$;
revoke all on function public.jf_delivery_methods(uuid),public.jf_delivery_method_save(uuid,uuid,jsonb,text),public.jf_delivery_method_remove(uuid,uuid),public.jf_phone_own_record(uuid,text),public.jf_courier_reserve(uuid,uuid,uuid),public.jf_delivery_method_secrets(uuid,uuid),public.jf_delivery_method_checked(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.jf_delivery_methods(uuid),public.jf_delivery_method_save(uuid,uuid,jsonb,text),public.jf_delivery_method_remove(uuid,uuid),public.jf_phone_own_record(uuid,text),public.jf_courier_reserve(uuid,uuid,uuid) to authenticated;
revoke all on function public.jf_save_order(uuid,uuid,jsonb),public.jf_courier_access(uuid,uuid) from public,anon,authenticated;
grant execute on function public.jf_save_order(uuid,uuid,jsonb),public.jf_courier_access(uuid,uuid) to authenticated;
grant execute on function public.jf_delivery_method_secrets(uuid,uuid),public.jf_delivery_method_checked(uuid,uuid,text) to service_role;
insert into public.jf_schema_versions(version) values('026_courier_methods');
commit;
