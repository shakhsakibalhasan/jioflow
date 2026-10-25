-- Run once after 003. Operational writes use permission-checked transactions.
begin;
do $$ begin
 if not exists(select 1 from public.jf_schema_versions where version='003_account_provisioning') then
  raise exception 'Run migration 003 before migration 004.';
 end if;
end $$;

create function jioflow_private.has_permission(sid uuid, permission_name text) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.jf_shops where id=sid and active) and (jioflow_private.is_creator() or jioflow_private.owns_shop(sid)
 or (jioflow_private.reads_operations(sid) and exists(select 1 from public.jf_memberships m
   where m.shop_id=sid and m.user_id=(select auth.uid()) and m.role='admin'
    and m.status='active' and m.permissions->permission_name='true'::jsonb)));
$$;
revoke all on function jioflow_private.has_permission(uuid,text) from public,anon,authenticated;

create function jioflow_private.normalize_phone(raw_phone text) returns text
language plpgsql immutable set search_path = '' as $$
declare digits text;
begin
 digits := regexp_replace(translate(raw_phone,'০১২৩৪৫৬৭৮৯','0123456789'),'[^0-9]','','g');
 if digits ~ '^01[3-9][0-9]{8}$' then return '+88'||digits; end if;
 if digits ~ '^8801[3-9][0-9]{8}$' then return '+'||digits; end if;
 if digits ~ '^[1-9][0-9]{6,14}$' and left(trim(raw_phone),1)='+' then return '+'||digits; end if;
 raise exception 'Enter a valid Bangladeshi mobile number or international number with + country code.' using errcode='22023';
end $$;
revoke all on function jioflow_private.normalize_phone(text) from public,anon,authenticated;

create function public.jf_save_product(target_shop uuid, product_id uuid default null, details jsonb default '{}'::jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare pid uuid; sale numeric; cost numeric;
begin
 if not jioflow_private.has_permission(target_shop,'products') then raise exception 'Product editing is not permitted.' using errcode='42501'; end if;
 if jsonb_typeof(details)<>'object' or length(trim(coalesce(details->>'name',''))) not between 1 and 200 or length(coalesce(details->>'description',''))>10000 or length(coalesce(details->>'sku',''))>120 then raise exception 'Check product name, SKU and description.' using errcode='22023'; end if;
 if coalesce(details->>'sale_price','') !~ '^[0-9]{1,12}(\.[0-9]{1,2})?$' then raise exception 'Enter a valid non-negative price with up to two decimals.' using errcode='22023'; end if;
 sale := (details->>'sale_price')::numeric;
 if details ? 'unit_cost' then
  if not jioflow_private.reads_finance(target_shop) then raise exception 'Cost access is not permitted.' using errcode='42501'; end if;
  if coalesce(details->>'unit_cost','') !~ '^[0-9]{1,12}(\.[0-9]{1,2})?$' then raise exception 'Enter a valid product cost.' using errcode='22023'; end if;
  cost := (details->>'unit_cost')::numeric;
 end if;
 if product_id is null then
  insert into public.jf_products(shop_id,name,sku,description,sale_price,active)
  values(target_shop,trim(details->>'name'),nullif(trim(details->>'sku'),''),coalesce(details->>'description',''),sale,coalesce((details->>'active')::boolean,true)) returning id into pid;
 else
  update public.jf_products set name=trim(details->>'name'),sku=nullif(trim(details->>'sku'),''),description=coalesce(details->>'description',''),sale_price=sale,active=coalesce((details->>'active')::boolean,active),updated_at=now()
  where id=product_id and shop_id=target_shop and archived_at is null returning id into pid;
  if pid is null then raise exception 'Product not found in this business.' using errcode='P0002'; end if;
 end if;
 if cost is not null then
  insert into public.jf_product_costs(shop_id,product_id,unit_cost) values(target_shop,pid,cost)
  on conflict on constraint jf_product_costs_pkey do update set unit_cost=excluded.unit_cost,updated_at=now();
 end if;
 return pid;
end $$;
create function public.jf_set_product_active(target_shop uuid, product_id uuid, is_active boolean) returns uuid
language plpgsql security definer set search_path = '' as $$
declare pid uuid;
begin
 if not jioflow_private.has_permission(target_shop,'products') then raise exception 'Product editing is not permitted.' using errcode='42501'; end if;
 if is_active is null then raise exception 'Choose an active state.' using errcode='22023'; end if;
 update public.jf_products set active=is_active,updated_at=now() where shop_id=target_shop and id=product_id and archived_at is null returning id into pid;
 if pid is null then raise exception 'Product not found in this business.' using errcode='P0002'; end if;
 return pid;
end $$;

create function public.jf_save_customer(target_shop uuid, customer_id uuid default null, details jsonb default '{}'::jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare cid uuid; normalized text; assigned uuid; is_permanent boolean; old public.jf_customers%rowtype;
begin
 if not jioflow_private.has_permission(target_shop,'assign') then raise exception 'Customer editing is not permitted.' using errcode='42501'; end if;
 if jsonb_typeof(details)<>'object' or length(coalesce(details->>'phone',''))>80 or length(trim(coalesce(details->>'full_name',''))) not between 1 and 120 or length(coalesce(details->>'email',''))>254 or length(coalesce(details->>'address',''))>1000 or length(coalesce(details->>'district',''))>100 or length(coalesce(details->>'area',''))>100 or length(coalesce(details->>'source',''))>100 then raise exception 'Check the customer details.' using errcode='22023'; end if;
 normalized := jioflow_private.normalize_phone(details->>'phone');
 -- Serialize same-phone upserts so duplicate form submissions use one profile.
 perform pg_advisory_xact_lock(hashtextextended(target_shop::text||normalized,0));
 if customer_id is not null then
  select * into old from public.jf_customers where shop_id=target_shop and id=customer_id and archived_at is null for update;
  if not found then raise exception 'Customer not found in this business.' using errcode='P0002'; end if;
 else
  select * into old from public.jf_customers where shop_id=target_shop and phone=normalized for update;
  if old.archived_at is not null then raise exception 'This customer is archived. Restore it before editing.' using errcode='22023'; end if;
 end if;
 assigned := case when details ? 'assigned_membership_id' then nullif(details->>'assigned_membership_id','')::uuid else old.assigned_membership_id end;
 is_permanent := coalesce((details->>'permanent')::boolean,old.permanent,false);
 if assigned is not null and not exists(select 1 from public.jf_memberships m join public.jf_profiles p on p.id=m.user_id where m.id=assigned and m.shop_id=target_shop and m.role='agent' and m.status='active' and p.active and p.deleted_at is null) then raise exception 'Select an active Agent in this business.' using errcode='22023'; end if;
 if is_permanent and assigned is null then raise exception 'Assign an Agent before marking a permanent client.' using errcode='22023'; end if;
 if old.id is null then
  insert into public.jf_customers(shop_id,phone,full_name,email,address,district,area,source,assigned_membership_id,permanent)
  values(target_shop,normalized,trim(details->>'full_name'),coalesce(details->>'email',''),coalesce(details->>'address',''),coalesce(details->>'district',''),coalesce(details->>'area',''),coalesce(nullif(details->>'source',''),'manual'),assigned,is_permanent) returning id into cid;
 else
  update public.jf_customers set phone=normalized,full_name=trim(details->>'full_name'),email=coalesce(details->>'email',email),address=coalesce(details->>'address',address),district=coalesce(details->>'district',district),area=coalesce(details->>'area',area),source=coalesce(nullif(details->>'source',''),source),assigned_membership_id=assigned,permanent=is_permanent,updated_at=now() where id=old.id returning id into cid;
 end if;
 insert into public.jf_followups(shop_id,customer_id) values(target_shop,cid) on conflict on constraint jf_followups_shop_id_customer_id_key do nothing;
 return cid;
end $$;

create function public.jf_record_followup(target_shop uuid, customer_id uuid, followup_status text, call_result text default null, callback_time timestamptz default null, note_text text default '') returns uuid
language plpgsql security definer set search_path = '' as $$
declare fid uuid;
begin
 if not jioflow_private.has_permission(target_shop,'assign') then raise exception 'Follow-up editing is not permitted.' using errcode='42501'; end if;
 if followup_status not in ('pending','callback','completed','cancelled') or followup_status is null or length(note_text)>10000 then raise exception 'Check the follow-up status and note.' using errcode='22023'; end if;
 if call_result is not null and call_result not in ('not_attempted','no_answer','busy','not_connected','connected','positive','negative','intermediate') then raise exception 'Choose a valid call outcome.' using errcode='22023'; end if;
 if followup_status='callback' and callback_time is null then raise exception 'Select a callback date and time.' using errcode='22023'; end if;
 perform 1 from public.jf_customers where shop_id=target_shop and id=customer_id and archived_at is null for update;
 if not found then raise exception 'Customer not found in this business.' using errcode='P0002'; end if;
 insert into public.jf_followups(shop_id,customer_id,status,call_outcome,callback_at,last_contact_at,updated_by)
 values(target_shop,customer_id,followup_status,call_result,case when followup_status='callback' then callback_time end,now(),auth.uid())
 on conflict on constraint jf_followups_shop_id_customer_id_key do update set status=excluded.status,call_outcome=excluded.call_outcome,callback_at=excluded.callback_at,last_contact_at=excluded.last_contact_at,updated_by=excluded.updated_by,updated_at=now() returning id into fid;
 insert into public.jf_followup_events(shop_id,followup_id,actor_id,outcome,note,callback_at)
 values(target_shop,fid,auth.uid(),coalesce(call_result,followup_status),coalesce(note_text,''),case when followup_status='callback' then callback_time end);
 if length(trim(coalesce(note_text,'')))>0 then insert into public.jf_notes(shop_id,customer_id,body,author_id) values(target_shop,customer_id,trim(note_text),auth.uid()); end if;
 return fid;
end $$;
create index jf_customer_phone_prefix on public.jf_customers(shop_id,phone text_pattern_ops) where archived_at is null;
create function public.jf_customer_page(target_shop uuid, status_filter text default null, phone_prefix text default '', page_offset integer default 0) returns setof public.jf_customers
language plpgsql stable security invoker set search_path = '' as $$
begin
 if status_filter is not null and status_filter not in ('pending','callback','completed','cancelled') then raise exception 'Invalid status filter.' using errcode='22023'; end if;
 if phone_prefix is null or phone_prefix !~ '^\+?[0-9]{0,15}$' or page_offset is null or page_offset<0 then raise exception 'Invalid page or phone prefix.' using errcode='22023'; end if;
 return query select c.* from public.jf_customers c left join public.jf_followups f on f.shop_id=c.shop_id and f.customer_id=c.id
 where c.shop_id=target_shop and c.archived_at is null and c.phone like phone_prefix||'%'
 and (status_filter is null or coalesce(f.status,'pending')=status_filter)
 order by c.created_at desc,c.id desc limit 51 offset page_offset;
end $$;
revoke all on function public.jf_customer_page(uuid,text,text,integer) from public,anon,authenticated;
grant execute on function public.jf_customer_page(uuid,text,text,integer) to authenticated;

revoke all on function public.jf_save_product(uuid,uuid,jsonb),public.jf_set_product_active(uuid,uuid,boolean),public.jf_save_customer(uuid,uuid,jsonb),public.jf_record_followup(uuid,uuid,text,text,timestamptz,text) from public,anon,authenticated;
grant execute on function public.jf_save_product(uuid,uuid,jsonb),public.jf_set_product_active(uuid,uuid,boolean),public.jf_save_customer(uuid,uuid,jsonb),public.jf_record_followup(uuid,uuid,text,text,timestamptz,text) to authenticated;
insert into public.jf_schema_versions(version) values('004_products_customers_followups');
commit;
