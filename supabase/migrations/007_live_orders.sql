-- Run once after 006. Atomic real orders; no courier simulation.
begin;
do $$ begin if not exists(select 1 from public.jf_schema_versions where version='006_account_activation') then raise exception 'Apply migration 006 first.'; end if; end $$;
alter table public.jf_orders add column request_key uuid, add column shipping_note text not null default '', add column order_type text not null default 'new', add column original_order_id uuid, add column preferred_courier text not null default '', add constraint jf_orders_original_fk foreign key(shop_id,original_order_id) references public.jf_orders(shop_id,id),add constraint jf_orders_request_unique unique(shop_id,request_key);
create function public.jf_save_order(target_shop uuid,request_id uuid,details jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare oid uuid; cid uuid; pid uuid; item jsonb; p public.jf_products%rowtype; subtotal_value numeric:=0; price_value numeric; qty integer; discount_value numeric; delivery_value numeric; advance_value numeric; member_id uuid; parent_id uuid; phone_value text; status_value text; item_count int;
begin
 if not jioflow_private.has_permission(target_shop,'assign') then raise exception 'Order entry is not permitted.' using errcode='42501'; end if;
 if request_id is null then raise exception 'Order request ID is required.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(target_shop::text||request_id::text,0));
 select id into oid from public.jf_orders where shop_id=target_shop and request_key=request_id;
 if oid is not null then return oid; end if;
 if jsonb_typeof(details) is distinct from 'object' or jsonb_typeof(details->'items') is distinct from 'array' then raise exception 'Enter order details and products.'; end if;
 item_count:=jsonb_array_length(details->'items');if item_count<1 or item_count>1000 then raise exception 'Choose order items (up to 1000 line items per submission).'; end if;
 if length(trim(coalesce(details->>'full_name',''))) not between 1 and 120 or length(trim(coalesce(details->>'address',''))) not between 1 and 1000 or length(coalesce(details->>'note',''))>10000 then raise exception 'Check customer name, address and note.'; end if;
 phone_value:=jioflow_private.normalize_phone(details->>'phone');
 status_value:=coalesce(details->>'status','draft');if status_value not in ('draft','confirmed','ready_to_book') then raise exception 'Choose Draft, Confirmed or Ready to Book.'; end if;
 if coalesce(details->>'order_type','new') not in ('new','exchange','replacement') then raise exception 'Choose a valid order type.'; end if;
 if coalesce(details->>'source','manual') not in ('manual','phone','website','facebook','whatsapp','repeat_customer') then raise exception 'Choose a valid source.'; end if;
 foreach pid in array array(select distinct (v->>'product_id')::uuid from jsonb_array_elements(details->'items') v order by 1) loop
  perform 1 from public.jf_products where id=pid and shop_id=target_shop and active and archived_at is null for share;
  if not found then raise exception 'A product is inactive or outside this business.'; end if;
 end loop;
 for item in select * from jsonb_array_elements(details->'items') loop
  if coalesce(item->>'quantity','') !~ '^[1-9][0-9]{0,5}$' or coalesce(item->>'unit_price','') !~ '^[0-9]{1,10}(\.[0-9]{1,2})?$' then raise exception 'Check item quantity and price.'; end if;
  qty:=(item->>'quantity')::int;price_value:=(item->>'unit_price')::numeric;
  subtotal_value:=subtotal_value+qty*price_value;
 end loop;
 if subtotal_value>999999999999 then raise exception 'Order amount is too large.'; end if;
 if coalesce(details->>'discount','0') !~ '^[0-9]{1,12}(\.[0-9]{1,2})?$' or coalesce(details->>'delivery_charge','0') !~ '^[0-9]{1,12}(\.[0-9]{1,2})?$' or coalesce(details->>'advance','0') !~ '^[0-9]{1,12}(\.[0-9]{1,2})?$' then raise exception 'Check discount, delivery and advance amounts.'; end if;
 discount_value:=coalesce(details->>'discount','0')::numeric;delivery_value:=coalesce(details->>'delivery_charge','0')::numeric;advance_value:=coalesce(details->>'advance','0')::numeric;
 if discount_value>subtotal_value or advance_value>subtotal_value-discount_value+delivery_value then raise exception 'Discount or advance exceeds the order amount.'; end if;
 if advance_value>0 and (coalesce(details->>'payment_method','') not in ('bKash','Nagad','Bank Transfer','Cash') or length(trim(coalesce(details->>'transaction_id','')))=0) then raise exception 'Advance payment requires a method and transaction ID.'; end if;
 parent_id:=nullif(details->>'original_order_id','')::uuid;
 if coalesce(details->>'order_type','new')<>'new' and parent_id is null then raise exception 'Select the original order for exchange or replacement.'; end if;
 if parent_id is not null and not exists(select 1 from public.jf_orders where id=parent_id and shop_id=target_shop) then raise exception 'Original order not found in this business.'; end if;
 member_id:=nullif(details->>'assigned_membership_id','')::uuid;
 if member_id is not null and not exists(select 1 from public.jf_memberships m join public.jf_profiles pr on pr.id=m.user_id where m.id=member_id and m.shop_id=target_shop and m.role='agent' and m.status='active' and pr.active and pr.deleted_at is null) then raise exception 'Choose an active Agent in this business.'; end if;
 cid:=public.jf_save_customer(target_shop,null,jsonb_build_object('full_name',details->>'full_name','phone',phone_value,'address',details->>'address','area',coalesce(details->>'area',''),'source',coalesce(details->>'source','manual')));
 if member_id is null then select assigned_membership_id into member_id from public.jf_customers where id=cid; end if;
 oid:=gen_random_uuid();
 insert into public.jf_orders(id,shop_id,customer_id,order_number,request_key,assigned_membership_id,entered_by,status,source,recipient_name,recipient_phone,delivery_address,area,subtotal,discount,delivery_charge,shipping_note,order_type,original_order_id,preferred_courier,confirmed_at)
 values(oid,target_shop,cid,'JF-'||upper(replace(oid::text,'-','')),request_id,member_id,auth.uid(),status_value,coalesce(details->>'source','manual'),trim(details->>'full_name'),phone_value,trim(details->>'address'),coalesce(details->>'area',''),subtotal_value,discount_value,delivery_value,coalesce(details->>'note',''),coalesce(details->>'order_type','new'),parent_id,left(coalesce(details->>'courier',''),100),case when status_value<>'draft' then now() end);
 for item in select * from jsonb_array_elements(details->'items') loop
  select * into p from public.jf_products where id=(item->>'product_id')::uuid and shop_id=target_shop;
  insert into public.jf_order_items(shop_id,order_id,product_id,product_name,quantity,unit_price) values(target_shop,oid,p.id,p.name,(item->>'quantity')::int,(item->>'unit_price')::numeric);
 end loop;
 if advance_value>0 then insert into public.jf_payments(shop_id,order_id,amount,method,transaction_id,recorded_by) values(target_shop,oid,advance_value,details->>'payment_method',trim(details->>'transaction_id'),auth.uid());end if;
 insert into public.jf_order_events(shop_id,order_id,actor_id,status,note) values(target_shop,oid,auth.uid(),status_value,'Order created');
 return oid;
end $$;
create function public.jf_update_order(target_shop uuid,target_order uuid,details jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare old public.jf_orders%rowtype; next_status text; assigned uuid;
begin
 if not jioflow_private.has_permission(target_shop,'assign') then raise exception 'Order editing is not permitted.' using errcode='42501'; end if;
 if jsonb_typeof(details) is distinct from 'object' or exists(select 1 from jsonb_object_keys(details) k where k not in ('status','note','assigned_membership_id')) then raise exception 'Unsupported order field.'; end if;
 select * into old from public.jf_orders where id=target_order and shop_id=target_shop for update;if not found then raise exception 'Order not found.'; end if;
 if old.status not in ('draft','confirmed','ready_to_book') then raise exception 'This order requires courier-aware changes.';end if;
 next_status:=coalesce(details->>'status',old.status);if next_status not in ('draft','confirmed','ready_to_book','cancelled') then raise exception 'Choose a supported order status.';end if;
 if length(coalesce(details->>'note',''))>10000 then raise exception 'Note is too long.';end if;
 assigned:=case when details ? 'assigned_membership_id' then nullif(details->>'assigned_membership_id','')::uuid else old.assigned_membership_id end;
 if assigned is not null and not exists(select 1 from public.jf_memberships m join public.jf_profiles pr on pr.id=m.user_id where m.id=assigned and m.shop_id=target_shop and m.role='agent' and m.status='active' and pr.active and pr.deleted_at is null) then raise exception 'Choose an active Agent in this business.';end if;
 update public.jf_orders set status=next_status,assigned_membership_id=assigned,shipping_note=coalesce(details->>'note',shipping_note),updated_at=now(),confirmed_at=case when next_status in ('confirmed','ready_to_book') then coalesce(confirmed_at,now()) else confirmed_at end where id=old.id;
 insert into public.jf_order_events(shop_id,order_id,actor_id,status,note) values(target_shop,old.id,auth.uid(),next_status,'Order details updated');return old.id;
end $$;
revoke all on function public.jf_save_order(uuid,uuid,jsonb),public.jf_update_order(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.jf_save_order(uuid,uuid,jsonb),public.jf_update_order(uuid,uuid,jsonb) to authenticated;
insert into public.jf_schema_versions(version) values('007_live_orders');
commit;
