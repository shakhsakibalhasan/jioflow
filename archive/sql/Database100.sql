begin;
-- One canonical date source for imported orders. Never use upload/Created At.
create or replace function public.jf_import_date100(data jsonb) returns date
language plpgsql stable security invoker set search_path='' as $fn$
declare v text;
begin
 if jsonb_typeof(data->'original_columns')='array' then
  select x->>'value' into v from jsonb_array_elements(data->'original_columns') with ordinality t(x,n)
  where lower(regexp_replace(x->>'column','[^a-zA-Z0-9]','','g')) in('orderdate','orderedat','date')
  order by case when lower(regexp_replace(x->>'column','[^a-zA-Z0-9]','','g'))='orderdate' then 0 else 1 end,n limit 1;
  -- If original columns exist, absent/blank Order Date must stay unknown.
 else v:=coalesce(nullif(data->>'ordered_at',''),data->>'order_date');end if;
 return public.jf_filter_date(v);
end $fn$;
revoke all on function public.jf_import_date100(jsonb) from public,anon;
grant execute on function public.jf_import_date100(jsonb) to authenticated;
create or replace function public.jf_followup_order100(target_shop uuid,target_customer uuid,filters jsonb) returns jsonb language sql stable security invoker set search_path='' as $fn$
 select jsonb_build_object('order_date',order_date,'amount',amount) from (
 select public.jf_order_amount_value(h.details->>case when filters->>'af_payment_basis'='advance' then 'advance' else 'total' end) amount,public.jf_import_date100(h.details) order_date,h.id match_id
 from public.jf_order_history h join public.jf_customers c on c.shop_id=h.shop_id and c.id=h.customer_id where h.shop_id=target_shop and h.customer_id=target_customer
     and (nullif(filters->>'af_order_date','') is null or public.jf_import_date100(h.details)=(filters->>'af_order_date')::date)
     and (nullif(filters->>'af_order_from','') is null or public.jf_import_date100(h.details)>=(filters->>'af_order_from')::date)
     and (nullif(filters->>'af_order_to','') is null or public.jf_import_date100(h.details)<=(filters->>'af_order_to')::date)
     and (nullif(filters->>'af_imported_status','') is null or lower(h.details->>'status')=lower(filters->>'af_imported_status'))
     and (nullif(filters->>'af_sku','') is null or public.jf_import_filter_value(h.details,'sku') ilike '%'||(filters->>'af_sku')||'%')
     and (nullif(filters->>'af_source','') is null or lower(coalesce(nullif(public.jf_import_filter_value(h.details,'source'),''),c.source))=lower(filters->>'af_source'))
     and (nullif(filters->>'af_tag','') is null or public.jf_template_tag81(h.details,'custom_tag')=filters->>'af_tag')
     and (nullif(filters->>'af_tag2','') is null or public.jf_template_tag81(h.details,'custom_tag_2')=filters->>'af_tag2')
     and (nullif(filters->>'af_tag3','') is null or public.jf_template_tag81(h.details,'custom_tag_3')=filters->>'af_tag3')
     and public.jf_payment_filter_match(h.details->>case when filters->>'af_payment_basis'='advance' then 'advance' else 'total' end,filters->>'af_payment_ranges')
 union all select case when filters->>'af_payment_basis'='advance' then (select coalesce(sum(p.amount),0) from public.jf_payments p where p.shop_id=z.shop_id and p.order_id=z.id and p.status in('pending','verified')) else z.total end,(z.created_at at time zone 'Asia/Dhaka')::date,z.id from public.jf_orders z where z.shop_id=target_shop and z.customer_id=target_customer and z.archived_at is null
 and (coalesce(jioflow_private.reads_staff_operations(target_shop),false) or z.assigned_membership_id=jioflow_private.agent_member(target_shop) or (jioflow_private.agent_member(target_shop) is not null and z.entered_by=auth.uid()))
       and (nullif(filters->>'af_order_date','') is null or (z.created_at at time zone 'Asia/Dhaka')::date=(filters->>'af_order_date')::date)
       and (nullif(filters->>'af_order_from','') is null or (z.created_at at time zone 'Asia/Dhaka')::date>=(filters->>'af_order_from')::date)
       and (nullif(filters->>'af_order_to','') is null or (z.created_at at time zone 'Asia/Dhaka')::date<=(filters->>'af_order_to')::date)
       and (nullif(filters->>'af_source','') is null or lower(z.source)=lower(filters->>'af_source'))
       and public.jf_payment_filter_match(case when filters->>'af_payment_basis'='advance' then (select coalesce(sum(p.amount),0)::text from public.jf_payments p where p.shop_id=z.shop_id and p.order_id=z.id and p.status in('pending','verified')) else z.total::text end,filters->>'af_payment_ranges')
       and (nullif(filters->>'af_sku','') is null or exists(select 1 from public.jf_order_items i join public.jf_products p on p.shop_id=i.shop_id and p.id=i.product_id where i.shop_id=z.shop_id and i.order_id=z.id and p.sku ilike '%'||(filters->>'af_sku')||'%'))
 and nullif(filters->>'af_imported_status','') is null and nullif(filters->>'af_tag','') is null and nullif(filters->>'af_tag2','') is null and nullif(filters->>'af_tag3','') is null
 ) matched where jioflow_private.can_read_customer(target_shop,target_customer) and exists(select 1 from public.jf_customers c where c.shop_id=target_shop and c.id=target_customer and c.archived_at is null) order by order_date desc nulls last,match_id desc limit 1;
$fn$;
revoke all on function public.jf_followup_order100(uuid,uuid,jsonb) from public,anon;
grant execute on function public.jf_followup_order100(uuid,uuid,jsonb) to authenticated;

-- Replace dates in all existing guarded page/count/selection paths, preserving permissions.
do $patch$
declare r record;d text;changed text;start_at integer;stop_at integer;old text;
begin
 for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.prokind='f' and p.proname like 'jf_%' and p.proname not in('jf_import_date100','jf_followup_order100') loop
  d:=pg_get_functiondef(r.oid);changed:=d;
  changed:=replace(changed,$old$public.jf_filter_date(coalesce(h.details->>'ordered_at',h.details->>'order_date',h.details->>'created_at'))$old$,'public.jf_import_date100(h.details)');
  changed:=replace(changed,$old$public.jf_filter_date(coalesce(nullif(h.details->>'ordered_at',''),h.details->>'order_date'))$old$,'public.jf_import_date100(h.details)');
  start_at:=position($marker$'order_date',coalesce((select $marker$ in changed);
  if start_at>0 then
   stop_at:=position($marker$,'latest_note'$marker$ in substring(changed from start_at));
   if stop_at=0 then raise exception 'Review changed order-date projection before applying Update 100.';end if;
   old:=substring(changed from start_at for stop_at-1);
   changed:=replace(changed,old,$new$'order_date',public.jf_followup_order100(target_shop,p.id,filters)->>'order_date'$new$);
  end if;
  -- Date-filtered amounts describe the matching order, not the customer's lifetime sum.
  if position('public.jf_customer_order_amount(target_shop,p.id)' in changed)>0 and position('date_amount100' in changed)=0 then
   changed:=replace(changed,'public.jf_customer_order_amount(target_shop,p.id)', $new$case when /*date_amount100*/ coalesce(nullif(filters->>'af_order_date',''),nullif(filters->>'af_order_from',''),nullif(filters->>'af_order_to','')) is not null then (public.jf_followup_order100(target_shop,p.id,filters)->>'amount')::numeric else public.jf_customer_order_amount(target_shop,p.id) end$new$);
  end if;
  if changed<>d then execute changed;end if;
 end loop;
end $patch$;
commit;
