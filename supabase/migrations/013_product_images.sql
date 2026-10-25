begin;
create or replace function public.jf_save_product(target_shop uuid, product_id uuid default null, details jsonb default '{}'::jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare pid uuid; sale numeric; cost numeric;
begin
 if not jioflow_private.has_permission(target_shop,'products') then raise exception 'Product editing is not permitted.' using errcode='42501'; end if;
 if jsonb_typeof(details)<>'object' or length(trim(coalesce(details->>'name',''))) not between 1 and 200 or length(coalesce(details->>'description',''))>10000 or length(coalesce(details->>'sku',''))>120 then raise exception 'Check product name, SKU and description.' using errcode='22023'; end if;
 if coalesce(details->>'sale_price','') !~ '^[0-9]{1,12}(\.[0-9]{1,2})?$' then raise exception 'Enter a valid non-negative price with up to two decimals.' using errcode='22023'; end if;
 if details ? 'image_path' and (length(coalesce(details->>'image_path',''))>350000 or coalesce(details->>'image_path','') !~ '^(assets/[a-zA-Z0-9_-]+\.(png|jpg|jpeg|webp)|https://[^[:space:]<>"'']+|data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+)?$') then raise exception 'Invalid product image.' using errcode='22023'; end if;
 sale := (details->>'sale_price')::numeric;
 if details ? 'unit_cost' then
  if not jioflow_private.reads_finance(target_shop) then raise exception 'Cost access is not permitted.' using errcode='42501'; end if;
  if coalesce(details->>'unit_cost','') !~ '^[0-9]{1,12}(\.[0-9]{1,2})?$' then raise exception 'Enter a valid product cost.' using errcode='22023'; end if;
  cost := (details->>'unit_cost')::numeric;
 end if;
 if product_id is null then
  insert into public.jf_products(shop_id,name,sku,description,sale_price,active,image_path)
  values(target_shop,trim(details->>'name'),nullif(trim(details->>'sku'),''),coalesce(details->>'description',''),sale,coalesce((details->>'active')::boolean,true),nullif(details->>'image_path','')) returning id into pid;
 else
  update public.jf_products set name=trim(details->>'name'),sku=nullif(trim(details->>'sku'),''),description=coalesce(details->>'description',''),image_path=case when details ? 'image_path' then nullif(details->>'image_path','') else image_path end,sale_price=sale,active=coalesce((details->>'active')::boolean,active),updated_at=now()
  where id=product_id and shop_id=target_shop and archived_at is null returning id into pid;
  if pid is null then raise exception 'Product not found in this business.' using errcode='P0002'; end if;
 end if;
 if cost is not null then
  insert into public.jf_product_costs(shop_id,product_id,unit_cost) values(target_shop,pid,cost)
  on conflict on constraint jf_product_costs_pkey do update set unit_cost=excluded.unit_cost,updated_at=now();
 end if;
 return pid;
end $$;

create or replace function public.jf_add_ecory_catalog(target_shop uuid) returns integer
language plpgsql security definer set search_path = '' as $$
declare p jsonb; existing uuid; added integer:=0;
begin
 if not jioflow_private.has_permission(target_shop,'products') then raise exception 'Product editing is not permitted.' using errcode='42501'; end if;
 if not exists(select 1 from public.jf_shops where id=target_shop and lower(trim(name))='ecory' and active) then raise exception 'Select the Ecory business.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(target_shop::text||'ecory-catalog',0));
 for p in select value from jsonb_array_elements('[["Methimix", "methimix", "100g / 1 pack", 690, "Stomach & digestion"], ["Thankuan", "thankuan", "100g / 1 pack", 590, "Stomach & digestion"], ["Kostocare", "koshtocare", "1 pack", 590, "Stomach & digestion"], ["Seedmix Powder", "seedmix-powder", "200g", 590, "Stomach & digestion"], ["Beetroot Powder", "beetroot", "200g", 890, "Natural food"], ["Chia Seed", "chia", "500g", 450, "Natural food"], ["Seedmix", "seedmix", "250g", 590, "Natural food"], ["Rosella Tea", "rosella-tea", "100g", 590, "Natural food"], ["Honey", "honey", "Mustard flower / 500g", 350, "Natural food"], ["Sesamum Massage Oil", "sesamum", "Trial / 50ml", 390, "Pain care"], ["Arabian Energy Booster", "arabian", "1 pack", 890, "Wellness"], ["Ashwagandha Powder", "ashwagandha", "200g", 590, "Wellness"], ["Ashwashakti", "ashwashakti", "Trial", 490, "Wellness"], ["Sherbet-e-Barakah", "sherbet-e-barakah", "Small pack", 690, "Wellness"]]'::jsonb) loop
  select id into existing from public.jf_products where shop_id=target_shop and archived_at is null and (sku='ECORY-'||upper(p->>1) or lower(trim(name))=lower(p->>0)) order by created_at limit 1;
  if existing is null then
   perform public.jf_save_product(target_shop,null,jsonb_build_object('name',p->>0,'sku','ECORY-'||upper(p->>1),'description',p->>2,'sale_price',p->>3,'active',true,'image_path','assets/'||(p->>1)||'.png'));added:=added+1;
  else
   update public.jf_products set image_path='assets/'||(p->>1)||'.png',updated_at=now() where id=existing and coalesce(image_path,'')='';
  end if;
 end loop;
 return added;
end $$;
revoke all on function public.jf_add_ecory_catalog(uuid) from public,anon,authenticated;
grant execute on function public.jf_add_ecory_catalog(uuid) to authenticated;
insert into public.jf_schema_versions(version) values('013_product_images');
commit;
