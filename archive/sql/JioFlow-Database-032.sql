-- Apply after 024. Keys stay in Vercel server environment, never in browser tables.
begin;
do $$ begin if not exists(select 1 from public.jf_schema_versions where version='024_agent_report_dashboard') then raise exception 'Apply database update 024 first.';end if;end $$;
alter table public.jf_shipments
 add column if not exists provider_invoice text,
 add column if not exists request_payload jsonb,
 add column if not exists provider_status text,
 add column if not exists tracking_url text,
 add column if not exists booking_lease_until timestamptz,
 add column if not exists poll_lease_until timestamptz,
 add column if not exists last_checked_at timestamptz,
 add column if not exists last_error text;
create unique index if not exists jf_steadfast_invoice on public.jf_shipments(provider_invoice) where courier='steadfast';
create index if not exists jf_steadfast_poll_due on public.jf_shipments(last_checked_at nulls first) where courier='steadfast' and consignment_id is not null;
create table jioflow_private.courier_limits (
 shop_id uuid not null references public.jf_shops(id) on delete cascade,
 user_id uuid not null references public.jf_profiles(id) on delete cascade,
 window_start timestamptz not null, requests integer not null,
 primary key(shop_id,user_id)
);
revoke all on jioflow_private.courier_limits from public,anon,authenticated;

create or replace function public.jf_courier_access(target_shop uuid,target_order uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare o public.jf_orders; s public.jf_shipments; can_book boolean;
begin
 if not jioflow_private.session_allowed() or not jioflow_private.reads_operations(target_shop) or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null) then raise exception 'Courier access denied.' using errcode='42501';end if;
 can_book:=jioflow_private.has_permission(target_shop,'booking');
 if target_order is null then return jsonb_build_object('can_book',can_book,'can_configure',jioflow_private.has_permission(target_shop,'integration'));end if;
 select * into o from public.jf_orders where shop_id=target_shop and id=target_order and archived_at is null;
 if o.id is null or not jioflow_private.can_read_order(target_shop,target_order) or (jioflow_private.agent_member(target_shop) is not null and o.entered_by is distinct from auth.uid()) then raise exception 'Order access denied.' using errcode='42501';end if;
 select * into s from public.jf_shipments where shop_id=target_shop and order_id=o.id order by created_at desc limit 1;
 return jsonb_build_object('can_book',can_book,'order',jsonb_build_object('id',o.id,'status',o.status,'order_number',o.order_number,'recipient_name',o.recipient_name,'recipient_phone',o.recipient_phone,'delivery_address',o.delivery_address,'total',o.total,'advance',(select coalesce(sum(amount),0) from public.jf_payments where shop_id=target_shop and order_id=o.id and status in ('pending','verified'))),'shipment',case when s.id is null then null else to_jsonb(s)-'request_payload' end);
end $$;

create function public.jf_courier_rate(target_shop uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare used integer;
begin
 perform public.jf_courier_access(target_shop,null);
 insert into jioflow_private.courier_limits(shop_id,user_id,window_start,requests) values(target_shop,auth.uid(),now(),1)
 on conflict(shop_id,user_id) do update set requests=case when courier_limits.window_start<now()-interval '1 minute' then 1 else courier_limits.requests+1 end,window_start=case when courier_limits.window_start<now()-interval '1 minute' then now() else courier_limits.window_start end returning requests into used;
 return used<=30;
end $$;

create or replace function public.jf_courier_reserve(target_shop uuid,target_order uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare o public.jf_orders; s public.jf_shipments; a jsonb; amount numeric; phone text; payload jsonb;
begin
 a:=public.jf_courier_access(target_shop,target_order);
 if a->>'can_book'<>'true' then raise exception 'Courier booking permission required.' using errcode='42501';end if;
 select * into o from public.jf_orders where shop_id=target_shop and id=target_order for update;
 select * into s from public.jf_shipments where shop_id=target_shop and order_id=o.id order by created_at desc limit 1 for update;
 if s.consignment_id is not null then return jsonb_build_object('already_booked',true,'shipment',to_jsonb(s)-'request_payload');end if;
 if s.id is not null and s.courier<>'steadfast' then raise exception 'This order already has another courier shipment.';end if;
 if o.status not in ('confirmed','ready_to_book') then raise exception 'Confirm the order before booking.';end if;
 if s.booking_lease_until>now() then raise exception 'Booking is already being processed. Wait 90 seconds before checking again.';end if;
 if s.id is null or s.status='failed' then
  phone:=regexp_replace(o.recipient_phone,'^\+?88','');
  amount:=o.total-(a->'order'->>'advance')::numeric;
  if phone !~ '^01[0-9]{9}$' or length(trim(o.recipient_name)) not between 1 and 100 or length(trim(o.delivery_address)) not between 1 and 490 or length(coalesce(o.shipping_note,''))>480 or amount<0 or amount>1000000 then raise exception 'Check recipient name, phone, address, note and COD amount.';end if;
  if s.id is null then insert into public.jf_shipments(shop_id,order_id,courier,status,booked_by) values(target_shop,o.id,'steadfast','booking',auth.uid()) returning * into s;end if;
  payload:=jsonb_build_object('invoice','JF-'||s.id::text,'recipient_name',o.recipient_name,'recipient_phone',phone,'recipient_address',o.delivery_address,'cod_amount',amount,'note',coalesce(o.shipping_note,''));
  update public.jf_shipments set provider_invoice=payload->>'invoice',request_payload=payload where id=s.id;
 end if;
 update public.jf_shipments set booking_lease_until=now()+interval '90 seconds',status='booking' where id=s.id returning * into s;
 return jsonb_build_object('already_booked',false,'shipment_id',s.id,'payload',s.request_payload);
end $$;

-- Lock edits during an uncertain external booking. Preserve the original validator.
alter function public.jf_update_order(uuid,uuid,jsonb) rename to jf_update_order_before_courier;
revoke all on function public.jf_update_order_before_courier(uuid,uuid,jsonb) from public,anon,authenticated;
create function public.jf_update_order(target_shop uuid,target_order uuid,details jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.jf_orders where shop_id=target_shop and id=target_order for update;
 if exists(select 1 from public.jf_shipments where shop_id=target_shop and order_id=target_order and courier='steadfast' and status<>'failed') then raise exception 'Courier booking exists. Changes require courier reconciliation.';end if;
 return public.jf_update_order_before_courier(target_shop,target_order,details);
end $$;

create function public.jf_courier_reject(target_shop uuid,shipment_id uuid) returns boolean
language sql security definer set search_path='' as $$
 update public.jf_shipments set status='failed',booking_lease_until=null,last_error='Steadfast rejected the request. Check order details and merchant configuration.' where shop_id=target_shop and id=shipment_id and courier='steadfast' and consignment_id is null returning true;
$$;

-- Server-only transactional write; arbitrary browser status writes are forbidden.
create function public.jf_courier_apply(target_shop uuid,shipment_id uuid,provider_data jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.jf_shipments; next_status text; raw_status text; cid text; changed boolean; event_key text;
begin
 select * into s from public.jf_shipments where shop_id=target_shop and id=shipment_id and courier='steadfast' for update;
 if s.id is null then raise exception 'Shipment unavailable.';end if;
 raw_status:=provider_data->>'delivery_status';
 if raw_status is null then
  cid:=provider_data->'consignment'->>'consignment_id';
  if coalesce(provider_data->'consignment'->>'invoice','')<>s.provider_invoice or cid !~ '^[0-9]+$' then raise exception 'Booking response does not match the invoice.';end if;
  raw_status:=coalesce(provider_data->'consignment'->>'status','in_review');
 else cid:=s.consignment_id;end if;
 next_status:=case raw_status when 'delivered' then 'delivered' when 'partial_delivered' then 'partial_delivery' when 'cancelled' then 'cancelled' else 'booked' end;
 -- Never regress a final confirmed state because of an older/incomplete response.
 if s.status in ('delivered','partial_delivery','cancelled','returned') and next_status='booked' then next_status:=s.status;raw_status:=s.provider_status;end if;
 changed:=s.provider_status is distinct from raw_status;
 update public.jf_shipments set consignment_id=coalesce(s.consignment_id,cid),tracking_code=coalesce(provider_data->'consignment'->>'tracking_code',s.tracking_code),tracking_url=coalesce(provider_data->'consignment'->>'tracking_link',s.tracking_url),status=next_status,provider_status=raw_status,booked_at=coalesce(s.booked_at,now()),last_synced_at=now(),last_checked_at=now(),last_error=null,booking_lease_until=null,poll_lease_until=null where id=s.id;
 update public.jf_orders set status=next_status,updated_at=now(),completed_at=case when next_status in ('delivered','partial_delivery') then coalesce(completed_at,now()) else completed_at end where shop_id=target_shop and id=s.order_id;
 if changed then
  event_key:='status:'||raw_status;
  insert into public.jf_courier_events(shop_id,shipment_id,provider_event_id,status) values(target_shop,s.id,event_key,raw_status) on conflict do nothing;
  insert into public.jf_order_events(shop_id,order_id,status,note) values(target_shop,s.order_id,next_status,'Steadfast: '||raw_status);
 end if;
 return jsonb_build_object('changed',changed,'status',next_status,'provider_status',raw_status,'consignment_id',coalesce(s.consignment_id,cid));
end $$;

create function public.jf_courier_poll_claim(batch_size integer default 20) returns jsonb
language sql security definer set search_path='' as $$
 with due as (select s.id from public.jf_shipments s join public.jf_shops b on b.id=s.shop_id where s.courier='steadfast' and s.consignment_id is not null and s.status not in ('delivered','partial_delivery','cancelled','returned','failed') and b.active and b.archived_at is null and (s.poll_lease_until is null or s.poll_lease_until<now()) and (s.last_checked_at is null or s.last_checked_at<now()-interval '25 minutes') order by s.last_checked_at nulls first,s.created_at limit least(greatest(batch_size,1),20) for update of s skip locked), claimed as(update public.jf_shipments s set poll_lease_until=now()+interval '90 seconds' from due where s.id=due.id returning s.id,s.shop_id,s.consignment_id) select coalesce(jsonb_agg(to_jsonb(claimed)),'[]'::jsonb) from claimed;
$$;
create function public.jf_courier_poll_error(target_shop uuid,shipment_id uuid,error_message text) returns boolean
language sql security definer set search_path='' as $$
 update public.jf_shipments set last_checked_at=now(),last_error=left(error_message,200),poll_lease_until=null where id=shipment_id and shop_id=target_shop and courier='steadfast' returning true;
$$;
revoke all on function public.jf_courier_access(uuid,uuid),public.jf_courier_reserve(uuid,uuid),public.jf_update_order(uuid,uuid,jsonb),public.jf_courier_apply(uuid,uuid,jsonb),public.jf_courier_poll_claim(integer),public.jf_courier_poll_error(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.jf_courier_rate(uuid),public.jf_courier_reject(uuid,uuid) from public,anon,authenticated;
grant execute on function public.jf_courier_rate(uuid) to authenticated;
grant execute on function public.jf_courier_reject(uuid,uuid) to service_role;
grant execute on function public.jf_courier_access(uuid,uuid),public.jf_courier_reserve(uuid,uuid),public.jf_update_order(uuid,uuid,jsonb) to authenticated;
grant execute on function public.jf_courier_apply(uuid,uuid,jsonb),public.jf_courier_poll_claim(integer),public.jf_courier_poll_error(uuid,uuid,text) to service_role;
create or replace function public.jf_finance_totals(target_shop uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not jioflow_private.has_permission(target_shop,'profit') then raise exception 'Finance access denied.' using errcode='42501';end if;
 with o as(select o.*,coalesce(f.product_cost,(select case when count(*)>0 and count(*)=count(pc.unit_cost) then sum(i.quantity*pc.unit_cost) end from public.jf_order_items i left join public.jf_product_costs pc on pc.shop_id=i.shop_id and pc.product_id=i.product_id where i.shop_id=target_shop and i.order_id=o.id)) product_cost,
 coalesce(f.courier_charge,o.delivery_charge)+coalesce(f.cod_fee,0)+coalesce(f.packaging_cost,0)+coalesce(f.return_cost,0)+coalesce(f.other_cost,0) fees,
 case when o.status='delivered' then greatest(0,coalesce(f.cod_expected,(select (s.request_payload->>'cod_amount')::numeric from public.jf_shipments s where s.shop_id=o.shop_id and s.order_id=o.id and s.courier='steadfast' and s.consignment_id is not null order by s.created_at desc limit 1),o.total-coalesce((select sum(amount) from public.jf_payments p where p.shop_id=target_shop and p.order_id=o.id and p.status='verified'),0))-coalesce(f.cod_received,0)) else 0 end cod_pending
 from public.jf_orders o left join public.jf_order_finance f on f.shop_id=o.shop_id and f.order_id=o.id where o.shop_id=target_shop and o.archived_at is null and o.status not in('draft','cancelled'))
 select jsonb_build_object('revenue',coalesce(sum(total),0),'product_cost',case when count(*)=count(product_cost) then coalesce(sum(product_cost),0) end,'fees',coalesce(sum(fees),0),'profit',case when count(*)=count(product_cost) then coalesce(sum(total-product_cost-fees),0) end,'cod_pending',coalesce(sum(cod_pending),0),'missing_cost_orders',count(*) filter(where product_cost is null),'agents',(select coalesce(jsonb_object_agg(t.member,t.profit),'{}') from(select coalesce(assigned_membership_id::text,'unassigned') member,case when count(*)=count(product_cost) then sum(total-product_cost-fees) end profit from o group by assigned_membership_id)t)) into result from o;
 return result;
end $$;
insert into public.jf_schema_versions(version) values('025_steadfast_integration');
commit;
