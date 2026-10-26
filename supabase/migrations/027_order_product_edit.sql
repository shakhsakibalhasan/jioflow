-- Apply after 026. Safe to rerun. Existing bookings and payment records are preserved.
begin;
do $$begin if not exists(select 1 from public.jf_schema_versions where version='026_courier_methods') then raise exception 'Apply database update 026 first.';end if;end$$;
create or replace function public.jf_edit_order_products(target_shop uuid,target_order uuid,details jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare old public.jf_orders%rowtype;p public.jf_products%rowtype;item jsonb;subtotal_value numeric:=0;discount_value numeric;delivery_value numeric;advance_value numeric;qty integer;price_value numeric;
begin
 if jsonb_typeof(details) is distinct from 'object' or exists(select 1 from jsonb_object_keys(details) k where k not in ('items','discount','delivery_charge')) then raise exception 'Unsupported order product field.';end if;
 if not jioflow_private.has_permission(target_shop,'assign') then raise exception 'Order editing is not permitted.' using errcode='42501';end if;
 -- Reuse all existing shop/account, visibility, status and courier-lock checks.
 perform public.jf_update_order(target_shop,target_order,'{}'::jsonb);
 select * into old from public.jf_orders where shop_id=target_shop and id=target_order for update;
 if jsonb_typeof(details->'items') is distinct from 'array' or jsonb_array_length(details->'items') not between 1 and 1000 then raise exception 'Choose valid order products.';end if;
 if (select count(*) from jsonb_array_elements(details->'items'))<>(select count(distinct i->>'product_id') from jsonb_array_elements(details->'items') i) then raise exception 'Combine repeated products into a single quantity.';end if;
 for item in select value from jsonb_array_elements(details->'items') order by value->>'product_id' loop
  select * into p from public.jf_products where shop_id=target_shop and id=(item->>'product_id')::uuid and active and archived_at is null for share;
  if not found then raise exception 'A product is inactive or outside this business.';end if;
  if coalesce(item->>'quantity','')!~'^[1-9][0-9]{0,5}$' or coalesce(item->>'unit_price','')!~'^[0-9]{1,10}(\.[0-9]{1,2})?$' then raise exception 'Check product quantity and price.';end if;
  qty:=(item->>'quantity')::integer;price_value:=(item->>'unit_price')::numeric;
  if jioflow_private.agent_member(target_shop) is not null and not jioflow_private.has_permission(target_shop,'price') and price_value<>p.sale_price and not exists(select 1 from public.jf_order_items where shop_id=target_shop and order_id=target_order and product_id=p.id and unit_price=price_value) then raise exception 'Price changes are not permitted.' using errcode='42501';end if;
  subtotal_value:=subtotal_value+qty*price_value;
 end loop;
 if subtotal_value>999999999999 then raise exception 'Order amount is too large.';end if;
 if coalesce(details->>'discount',old.discount::text)!~'^[0-9]{1,12}(\.[0-9]{1,2})?$' or coalesce(details->>'delivery_charge',old.delivery_charge::text)!~'^[0-9]{1,12}(\.[0-9]{1,2})?$' then raise exception 'Check discount and delivery charge.';end if;
 discount_value:=coalesce((details->>'discount')::numeric,old.discount);delivery_value:=coalesce((details->>'delivery_charge')::numeric,old.delivery_charge);
 if jioflow_private.agent_member(target_shop) is not null and discount_value<>old.discount and not jioflow_private.has_permission(target_shop,'discount') then raise exception 'Discount changes are not permitted.' using errcode='42501';end if;
 perform 1 from public.jf_payments where shop_id=target_shop and order_id=target_order for update;
 select coalesce(sum(amount),0) into advance_value from public.jf_payments where shop_id=target_shop and order_id=target_order and status in ('pending','verified');
 if discount_value>subtotal_value or advance_value>subtotal_value-discount_value+delivery_value then raise exception 'Order total cannot be below its discount or recorded advance.';end if;
 delete from public.jf_order_items where shop_id=target_shop and order_id=target_order;
 for item in select value from jsonb_array_elements(details->'items') loop
  select * into p from public.jf_products where shop_id=target_shop and id=(item->>'product_id')::uuid;
  insert into public.jf_order_items(shop_id,order_id,product_id,product_name,quantity,unit_price) values(target_shop,target_order,p.id,p.name,(item->>'quantity')::integer,(item->>'unit_price')::numeric);
 end loop;
 update public.jf_orders set subtotal=subtotal_value,discount=discount_value,delivery_charge=delivery_value,updated_at=now() where shop_id=target_shop and id=target_order;
 return jsonb_build_object('id',target_order,'subtotal',subtotal_value,'discount',discount_value,'delivery_charge',delivery_value,'total',subtotal_value-discount_value+delivery_value);
end $$;
revoke all on function public.jf_edit_order_products(uuid,uuid,jsonb) from public,anon;
grant execute on function public.jf_edit_order_products(uuid,uuid,jsonb) to authenticated;
insert into public.jf_schema_versions(version) values('027_order_product_edit') on conflict do nothing;
commit;
