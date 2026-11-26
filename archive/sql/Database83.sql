begin;
create or replace function public.jf_followup_amount83(target_shop uuid,target_customer uuid,filters jsonb) returns numeric
language sql stable security invoker set search_path='' as $fn$
 select min(amount) from (
 select public.jf_order_amount_value(h.details->>case when filters->>'af_payment_basis'='advance' then 'advance' else 'total' end) amount
 from public.jf_order_history h join public.jf_customers c on c.shop_id=h.shop_id and c.id=h.customer_id where h.shop_id=target_shop and h.customer_id=target_customer
     and (nullif(filters->>'af_order_date','') is null or public.jf_filter_date(coalesce(h.details->>'ordered_at',h.details->>'order_date',h.details->>'created_at'))=(filters->>'af_order_date')::date)
     and (nullif(filters->>'af_order_from','') is null or public.jf_filter_date(coalesce(h.details->>'ordered_at',h.details->>'order_date',h.details->>'created_at'))>=(filters->>'af_order_from')::date)
     and (nullif(filters->>'af_order_to','') is null or public.jf_filter_date(coalesce(h.details->>'ordered_at',h.details->>'order_date',h.details->>'created_at'))<=(filters->>'af_order_to')::date)
     and (nullif(filters->>'af_imported_status','') is null or lower(h.details->>'status')=lower(filters->>'af_imported_status'))
     and (nullif(filters->>'af_sku','') is null or public.jf_import_filter_value(h.details,'sku') ilike '%'||(filters->>'af_sku')||'%')
     and (nullif(filters->>'af_source','') is null or lower(coalesce(nullif(public.jf_import_filter_value(h.details,'source'),''),c.source))=lower(filters->>'af_source'))
     and (nullif(filters->>'af_tag','') is null or public.jf_template_tag81(h.details,'custom_tag')=filters->>'af_tag')
     and (nullif(filters->>'af_tag2','') is null or public.jf_template_tag81(h.details,'custom_tag_2')=filters->>'af_tag2')
     and (nullif(filters->>'af_tag3','') is null or public.jf_template_tag81(h.details,'custom_tag_3')=filters->>'af_tag3')
     and public.jf_payment_filter_match(h.details->>case when filters->>'af_payment_basis'='advance' then 'advance' else 'total' end,filters->>'af_payment_ranges')
 union all select case when filters->>'af_payment_basis'='advance' then (select coalesce(sum(p.amount),0) from public.jf_payments p where p.shop_id=z.shop_id and p.order_id=z.id and p.status in('pending','verified')) else z.total end from public.jf_orders z where z.shop_id=target_shop and z.customer_id=target_customer and z.archived_at is null
       and (nullif(filters->>'af_order_date','') is null or (z.created_at at time zone 'Asia/Dhaka')::date=(filters->>'af_order_date')::date)
       and (nullif(filters->>'af_order_from','') is null or (z.created_at at time zone 'Asia/Dhaka')::date>=(filters->>'af_order_from')::date)
       and (nullif(filters->>'af_order_to','') is null or (z.created_at at time zone 'Asia/Dhaka')::date<=(filters->>'af_order_to')::date)
       and (nullif(filters->>'af_source','') is null or lower(z.source)=lower(filters->>'af_source'))
       and public.jf_payment_filter_match(case when filters->>'af_payment_basis'='advance' then (select coalesce(sum(p.amount),0)::text from public.jf_payments p where p.shop_id=z.shop_id and p.order_id=z.id and p.status in('pending','verified')) else z.total::text end,filters->>'af_payment_ranges')
       and (nullif(filters->>'af_sku','') is null or exists(select 1 from public.jf_order_items i join public.jf_products p on p.shop_id=i.shop_id and p.id=i.product_id where i.shop_id=z.shop_id and i.order_id=z.id and p.sku ilike '%'||(filters->>'af_sku')||'%'))
 and nullif(filters->>'af_imported_status','') is null and nullif(filters->>'af_tag','') is null and nullif(filters->>'af_tag2','') is null and nullif(filters->>'af_tag3','') is null
 ) matched;
$fn$;
do $patch$
declare r record; definition text;
begin
 for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in('public','jioflow_private') and p.proname in('jf_workspace_page','jf_workspace_page_rls73','jf_workspace_page_staff73','jf_agent_page78','jf_selection_rls74','jf_selection_staff74') loop
 definition:=pg_get_functiondef(r.oid);
 if position('public.jf_customer_order_amount(target_shop,p.id)' in definition)>0 then
 definition:=replace(definition,'public.jf_customer_order_amount(target_shop,p.id)', $replace$case when nullif(filters->>'af_payment_ranges','') is not null then public.jf_followup_amount83(target_shop,p.id,filters) else public.jf_customer_order_amount(target_shop,p.id) end$replace$);
 execute definition;
 end if;
 end loop;
end $patch$;
-- Use the same guarded Agent scope for full details as for the fast list.
do $agent$
declare definition text;
begin
 definition:=pg_get_functiondef('jioflow_private.jf_agent_page78(uuid,text,jsonb,integer)'::regprocedure);
 definition:=replace(definition, 'filters:=coalesce(filters,''{}'')||''{"_fast":true}'';', 'filters:=coalesce(filters,''{}'');');
 execute definition;
 definition:=pg_get_functiondef('public.jf_workspace_page_fast(uuid,text,jsonb,integer)'::regprocedure);
 definition:=replace(definition,'jioflow_private.jf_agent_page78(target_shop,entity,filters,page_number)', 'jioflow_private.jf_agent_page78(target_shop,entity,coalesce(filters,''{}'')||''{"_fast":true}'',page_number)');
 execute definition;
end $agent$;
create or replace function public.jf_workspace_page(target_shop uuid,entity text,filters jsonb default '{}',page_number integer default 0) returns jsonb
language plpgsql stable security invoker set search_path='' as $page$
begin
 if coalesce(jioflow_private.reads_staff_operations(target_shop),false) then return jioflow_private.jf_workspace_page_staff73(target_shop,entity,filters,page_number);end if;
 if jioflow_private.agent_member(target_shop) is not null then return jioflow_private.jf_agent_page78(target_shop,entity,coalesce(filters,'{}')||'{"_fast":false}',page_number);end if;
 return public.jf_workspace_page_rls73(target_shop,entity,filters,page_number);
end $page$;
commit;
