begin;
do $$begin if not exists(select 1 from public.jf_schema_versions where version='040_courier_branding') then raise exception 'Apply Database58.sql first.';end if;end$$;
create or replace function public.jf_delivery_method_save_before_branding(target_shop uuid,method_id uuid,details jsonb,encrypted_keys text default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare a jsonb; m public.jf_courier_methods; rid uuid; use_active boolean; use_default boolean;
begin
 a:=public.jf_courier_access(target_shop,null);
 if a->>'can_configure'<>'true' or jioflow_private.agent_member(target_shop) is not null then raise exception 'Integration permission required.' using errcode='42501';end if;
 perform 1 from public.jf_shops where id=target_shop for update;
 if jsonb_typeof(details)<>'object' or exists(select 1 from jsonb_object_keys(details) k where k not in('name','provider','active','preferred','booking_enabled','default_note','send_product_names','provider_options')) or length(trim(coalesce(details->>'name',''))) not between 1 and 100 or coalesce(details->>'provider','') not in('steadfast','pathao','custom') or length(coalesce(details->>'default_note',''))>480 then raise exception 'Check the courier details.';end if;
 if exists(select 1 from jsonb_each(details) p where p.key in('active','preferred','booking_enabled','send_product_names') and jsonb_typeof(p.value)<>'boolean') then raise exception 'Check the courier switches.';end if;
 if method_id is not null then select * into m from public.jf_courier_methods where id=method_id and shop_id=target_shop and deleted_at is null for update;if m.id is null and (encrypted_keys is null or exists(select 1 from public.jf_courier_methods where id=method_id)) then raise exception 'Courier method unavailable.';end if;end if;
 if m.id is not null and m.provider is distinct from details->>'provider' then raise exception 'Add a separate method to change courier provider.';end if;
 if m.id is not null and m.provider='custom' and lower(coalesce(m.provider_options->>'courier_type','')) is distinct from lower(coalesce(details->'provider_options'->>'courier_type','')) then raise exception 'Add a separate method to change courier type.';end if;
 if details->>'provider'='custom' and lower(coalesce(details->'provider_options'->>'courier_type',''))<>'ecourier' and (coalesce((details->>'booking_enabled')::boolean,false) or coalesce((details->>'preferred')::boolean,false) or length(trim(coalesce(details->'provider_options'->>'courier_type',''))) not between 1 and 80) then raise exception 'Custom courier needs a backend adapter before enabling booking.';end if;
 if details->>'provider'='pathao' and (jsonb_typeof(details->'provider_options') is distinct from 'object' or coalesce(details->'provider_options'->>'environment','') not in('production','sandbox') or coalesce(details->'provider_options'->>'store_id','') !~ '^[1-9][0-9]{0,9}$' or coalesce(details->'provider_options'->>'item_weight','') !~ '^[0-9]+([.][0-9]+)?$' or (details->'provider_options'->>'item_weight')::numeric not between .5 and 10 or coalesce(details->'provider_options'->>'delivery_type','') not in('12','48') or coalesce(details->'provider_options'->>'item_type','') not in('1','2')) then raise exception 'Check Pathao settings.';end if;
 if details->>'provider'='custom' and lower(details->'provider_options'->>'courier_type')='ecourier' and length(trim(coalesce(details->'provider_options'->>'package_code',''))) not between 1 and 80 then raise exception 'Enter eCourier package code.';end if;
 if encrypted_keys is not null and (length(encrypted_keys) not between 40 and 40000 or encrypted_keys !~ '^v1[.]') then raise exception 'Invalid encrypted credentials.';end if;
 if m.id is null and encrypted_keys is null then raise exception 'Enter both API keys.';end if;
 if m.id is not null and encrypted_keys is not null and exists(select 1 from public.jf_shipments where shop_id=target_shop and jf_shipments.method_id=m.id and status not in('delivered','partial_delivery','cancelled','returned','failed')) then raise exception 'This method has open shipments. Add a new method to change its credentials.';end if;
 use_active:=coalesce((details->>'active')::boolean,true);use_default:=use_active and coalesce((details->>'preferred')::boolean,false);
 if use_default then update public.jf_courier_methods set preferred=false where shop_id=target_shop and preferred;end if;
 rid:=coalesce(m.id,method_id,gen_random_uuid());
 insert into public.jf_courier_methods(id,shop_id,provider,name,sealed,active,preferred,booking_enabled,default_note,send_product_names,provider_options)
 values(rid,target_shop,details->>'provider',trim(details->>'name'),coalesce(encrypted_keys,m.sealed),use_active,use_default,coalesce((details->>'booking_enabled')::boolean,false),coalesce(details->>'default_note',''),coalesce((details->>'send_product_names')::boolean,false),coalesce(details->'provider_options','{}'))
 on conflict(id) do update set name=excluded.name,provider_options=excluded.provider_options,sealed=excluded.sealed,active=excluded.active,preferred=excluded.preferred,booking_enabled=excluded.booking_enabled,default_note=excluded.default_note,send_product_names=excluded.send_product_names,updated_at=now(),checked_at=case when encrypted_keys is null and excluded.provider_options=jf_courier_methods.provider_options then jf_courier_methods.checked_at else null end,check_status=case when encrypted_keys is null and excluded.provider_options=jf_courier_methods.provider_options then jf_courier_methods.check_status else null end where jf_courier_methods.shop_id=target_shop and jf_courier_methods.deleted_at is null;
 return rid;
end $$;
create or replace function public.jf_ecourier_reserve(target_shop uuid,target_order uuid,target_method uuid,delivery jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare a jsonb;o public.jf_orders;s public.jf_shipments;m public.jf_courier_methods;amount numeric;phone text;payload jsonb;qty integer;
begin
 a:=public.jf_courier_access(target_shop,target_order);
 if not coalesce((a->>'can_book')::boolean,false) then raise exception 'Courier booking permission required.' using errcode='42501';end if;
 select * into m from public.jf_courier_methods where shop_id=target_shop and id=target_method and provider='custom' and lower(provider_options->>'courier_type')='ecourier' and active and deleted_at is null and booking_enabled and check_status='verified';
 if m.id is null then raise exception 'Choose a verified active eCourier method with booking enabled.';end if;
 select * into o from public.jf_orders where shop_id=target_shop and id=target_order for update;
 select * into s from public.jf_shipments where shop_id=target_shop and order_id=o.id order by created_at desc limit 1 for update;
 if s.id is not null and (s.courier<>'ecourier' or s.method_id is distinct from target_method) then raise exception 'This order already uses another delivery method.';end if;
 if s.consignment_id is not null then return jsonb_build_object('already_booked',true,'shipment',to_jsonb(s)-'request_payload');end if;
 if s.id is not null and s.status<>'failed' then raise exception 'eCourier booking needs reconciliation. Check the merchant panel and attach the Consignment ID before any retry.';end if;
 if o.status not in('confirmed','ready_to_book') then raise exception 'Confirm the order before booking.';end if;
 phone:=regexp_replace(o.recipient_phone,'^\+?88','');amount:=o.total-(a->'order'->>'advance')::numeric;
 if phone !~ '^01[0-9]{9}$' or length(trim(o.recipient_name)) not between 1 and 250 or length(trim(o.delivery_address)) not between 1 and 40 or amount<=0 or amount<>trunc(amount) or amount>1000000 then raise exception 'eCourier needs a name, address up to 40 characters, Bangladesh phone and whole-taka COD.';end if;
 qty:=1; -- One shipment/parcel per CRM order; product quantities go in item_description.
 if s.id is null then insert into public.jf_shipments(shop_id,order_id,courier,status,booked_by,method_id) values(target_shop,o.id,'ecourier','booking',auth.uid(),target_method) returning * into s;end if;
 if jsonb_typeof(delivery) is distinct from 'object' or exists(select 1 from jsonb_object_keys(delivery) k where k not in('city','thana','area','zip')) or exists(select 1 from jsonb_each_text(delivery) p where length(trim(p.value)) not between 1 and 40) or not(delivery ?& array['city','thana','area','zip']) then raise exception 'Enter eCourier city, thana, area and postcode.';end if;
 payload:=jsonb_build_object('recipient_name',o.recipient_name,'recipient_mobile',phone,'recipient_address',o.delivery_address,'recipient_city',delivery->>'city','recipient_thana',delivery->>'thana','recipient_area',delivery->>'area','recipient_zip',delivery->>'zip','package_code',m.provider_options->>'package_code','product_price',amount,'payment_method','COD','parcel_type','BOX','sending_type',case when o.order_type='exchange' then 2 else 1 end,'product_id','JF'||left(replace(s.id::text,'-',''),18),'comments',left(coalesce(nullif(o.shipping_note,''),m.default_note,''),255));
 if m.send_product_names then payload:=payload||jsonb_build_object('special_instruction',(select left(string_agg(product_name||' x '||quantity,', ' order by id),255) from public.jf_order_items where shop_id=target_shop and order_id=o.id));end if;
 update public.jf_shipments set request_payload=payload,provider_invoice=payload->>'product_id',status='booking',booking_lease_until=now()+interval '90 seconds',last_error=null where id=s.id;
 return jsonb_build_object('already_booked',false,'shipment_id',s.id,'payload',payload);
end$$;
create or replace function public.jf_ecourier_reject(target_shop uuid,shipment_id uuid) returns boolean language sql security definer set search_path='' as $$
 update public.jf_shipments set status='failed',booking_lease_until=null,last_error='eCourier rejected this request. Correct parcel details or connection before retrying.' where shop_id=target_shop and id=shipment_id and courier='ecourier' and consignment_id is null returning true;
$$;
create or replace function public.jf_ecourier_apply(target_shop uuid,shipment_id uuid,provider_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.jf_shipments;raw text;next_status text;cid text;changed boolean;
begin
 select * into s from public.jf_shipments where shop_id=target_shop and id=shipment_id and courier='ecourier' for update;
 if s.id is null then raise exception 'Shipment unavailable.';end if;
 cid:=provider_data->>'consignment_id';
 if coalesce(provider_data->>'merchant_order_id','')<>s.provider_invoice or coalesce(cid,'') !~ '^[A-Za-z0-9-]{1,100}$' or (s.consignment_id is not null and s.consignment_id<>cid) then raise exception 'eCourier response does not match the saved invoice.';end if;
 raw:=coalesce(provider_data->>'order_status_slug',provider_data->>'order_status','Pending');
 if length(raw)>100 then raise exception 'Unrecognized eCourier status.';end if;
 next_status:=case lower(replace(replace(raw,' ','-'),'_','-')) when 'initiated' then 'booked' when 'picked-up' then 'in_transit' when 'in-source-branch' then 'in_transit' when 'in-destination-branch' then 'in_transit' when 'on-the-way-to-delivery' then 'in_transit' when 'delivered' then 'delivered' when 'partial-delivery' then 'partial_delivery' when 'partial-delivered' then 'partial_delivery' when 'returned' then 'returned' when 'return' then 'returned' when 'cancelled' then 'cancelled' when 'canceled' then 'cancelled' when 'delivery-cancelled' then 'cancelled' when 'picked' then 'in_transit' when 'in-transit' then 'in_transit' when 'on-the-way' then 'in_transit' when 'out-for-delivery' then 'in_transit' when 'delivery-in-progress' then 'in_transit' else coalesce(nullif(s.status,'booking'),'booked') end;
 if s.status in('delivered','partial_delivery','returned','cancelled') and next_status in('booked','in_transit') then next_status:=s.status;raw:=s.provider_status;end if;
 changed:=s.provider_status is distinct from raw or s.consignment_id is null;
 update public.jf_shipments set consignment_id=cid,tracking_code=cid,provider_status=raw,status=next_status,booked_at=coalesce(booked_at,now()),last_checked_at=now(),last_synced_at=now(),last_error=null,booking_lease_until=null,poll_lease_until=null where id=s.id;
 update public.jf_orders set status=next_status,updated_at=now(),completed_at=case when next_status in('delivered','partial_delivery') then coalesce(completed_at,now()) else completed_at end where shop_id=target_shop and id=s.order_id;
 if changed then insert into public.jf_courier_events(shop_id,shipment_id,provider_event_id,status) values(target_shop,s.id,'status:'||raw,raw) on conflict do nothing;insert into public.jf_order_events(shop_id,order_id,status,note) values(target_shop,s.order_id,next_status,'eCourier: '||raw);end if;
 return jsonb_build_object('changed',changed,'status',next_status,'provider_status',raw,'consignment_id',cid);
end$$;
-- Prevent edits and cross-provider switches during booked or uncertain shipments.
create or replace function public.jf_update_order(target_shop uuid,target_order uuid,details jsonb) returns uuid language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.jf_orders where shop_id=target_shop and id=target_order for update;
 if exists(select 1 from public.jf_shipments where shop_id=target_shop and order_id=target_order and courier in('steadfast','pathao','ecourier') and status<>'failed') then raise exception 'Courier booking exists. Changes require courier reconciliation.';end if;
 return public.jf_update_order_before_courier(target_shop,target_order,details);
end$$;
create or replace function public.jf_courier_poll_claim(batch_size integer default 20) returns jsonb language sql security definer set search_path='' as $$
 with due as(select s.id from public.jf_shipments s join public.jf_shops b on b.id=s.shop_id where s.courier in('steadfast','pathao','ecourier') and s.consignment_id is not null and s.status not in('delivered','partial_delivery','cancelled','returned','failed') and b.active and b.archived_at is null and (s.poll_lease_until is null or s.poll_lease_until<now()) and (s.last_checked_at is null or s.last_checked_at<now()-interval '25 minutes') order by s.last_checked_at nulls first,s.created_at limit least(greatest(batch_size,1),20) for update of s skip locked),claimed as(update public.jf_shipments s set poll_lease_until=now()+interval '90 seconds' from due where s.id=due.id returning s.id,s.shop_id,s.consignment_id,s.method_id,s.courier,s.provider_invoice) select coalesce(jsonb_agg(to_jsonb(claimed)),'[]') from claimed;
$$;
create or replace function public.jf_courier_poll_error(target_shop uuid,shipment_id uuid,error_message text) returns boolean language sql security definer set search_path='' as $$update public.jf_shipments set last_checked_at=now(),last_error=left(error_message,200),poll_lease_until=null where id=shipment_id and shop_id=target_shop and courier in('steadfast','pathao','ecourier') returning true$$;
revoke all on function public.jf_ecourier_reserve(uuid,uuid,uuid,jsonb),public.jf_ecourier_reject(uuid,uuid),public.jf_ecourier_apply(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.jf_ecourier_reserve(uuid,uuid,uuid,jsonb) to authenticated;
grant execute on function public.jf_ecourier_reject(uuid,uuid),public.jf_ecourier_apply(uuid,uuid,jsonb) to service_role;
insert into public.jf_schema_versions(version) values('041_ecourier') on conflict do nothing;
commit;
