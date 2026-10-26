-- Full pre-booking recipient editing, with existing status/tenant/courier locks.
begin;
do $$begin if not exists(select 1 from public.jf_schema_versions where version='029_shared_live_workflow') then raise exception 'Apply migration 029 first.';end if;end$$;
create or replace function public.jf_edit_order_details(target_shop uuid,target_order uuid,details jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare patch jsonb:='{}';k text;normalized text;old public.jf_orders%rowtype;
begin
 if jsonb_typeof(details) is distinct from 'object' or exists(select 1 from jsonb_object_keys(details) as keys(field_name) where keys.field_name not in('recipient_name','recipient_phone','delivery_address','area','source','status','note','assigned_membership_id')) then raise exception 'Unsupported order field.';end if;
 for k in select jsonb_object_keys(details) loop if k in('status','note','assigned_membership_id') then patch:=patch||jsonb_build_object(k,details->k);end if;end loop;
 -- This performs permission, session, order visibility, status, assignment and courier lease checks.
 perform public.jf_update_order(target_shop,target_order,patch);
 select * into old from public.jf_orders where shop_id=target_shop and id=target_order for update;
 if details?'recipient_name' and length(trim(coalesce(details->>'recipient_name',''))) not between 1 and 200 then raise exception 'Enter a customer name.';end if;
 if details?'delivery_address' and length(trim(coalesce(details->>'delivery_address',''))) not between 1 and 2000 then raise exception 'Enter a delivery address.';end if;
 if length(coalesce(details->>'area',''))>200 or length(coalesce(details->>'source',''))>100 then raise exception 'Area or source is too long.';end if;
 normalized:=case when details?'recipient_phone' then jioflow_private.normalize_phone(details->>'recipient_phone') else old.recipient_phone end;
 update public.jf_orders set recipient_name=coalesce(trim(details->>'recipient_name'),recipient_name),recipient_phone=normalized,delivery_address=coalesce(trim(details->>'delivery_address'),delivery_address),area=coalesce(details->>'area',area),source=coalesce(details->>'source',source),updated_at=now() where shop_id=target_shop and id=target_order;
 return target_order;
end$$;
revoke all on function public.jf_edit_order_details(uuid,uuid,jsonb) from public,anon;
grant execute on function public.jf_edit_order_details(uuid,uuid,jsonb) to authenticated;
insert into public.jf_schema_versions(version) values('030_order_recipient_edit') on conflict do nothing;
commit;
