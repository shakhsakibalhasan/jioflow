begin;
-- Precompute confirmation labels once per query, rather than rereading settings per customer.
create or replace function jioflow_private.confirmed_labels149(target_shop uuid)
returns text[] language sql stable security definer set search_path='' as $$
 select coalesce(array_agg(distinct x->>'name'),'{}'::text[])
 from jsonb_array_elements(jioflow_private.status_definitions(target_shop)||jioflow_private.permanent_status_definitions(target_shop)) x
 where x->>'kind'='confirm' and (x->>'active')::boolean
$$;
revoke all on function jioflow_private.confirmed_labels149(uuid) from public,anon,authenticated;
do $patch$
declare f record;d text;begin
 for f in select p.oid,n.nspname,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in('public','jioflow_private') and p.prokind='f' and p.proname in
 ('jf_agent_report','jf_workspace_summary','jf_agent_workspace_summary','jf_agent_page78','jf_selection_rls74','jf_selection_staff74','jf_workspace_page_rls73','jf_workspace_page_staff73') loop
 d:=pg_get_functiondef(f.oid);
 d:=replace(d,'jioflow_private.confirmed_workflow142(target_shop,c.workflow_label)','(c.workflow_label=any((select jioflow_private.confirmed_labels149(target_shop))::text[]))');
 d:=replace(d,'jioflow_private.confirmed_workflow142(target_shop,workflow_label)','(workflow_label=any((select jioflow_private.confirmed_labels149(target_shop))::text[]))');
 if d<>pg_get_functiondef(f.oid) then execute d;end if;
 end loop;
end $patch$;
-- Parameter-specific plans prevent generic OR-filter plans degrading after repeated calls.
do $plans$
declare f record;begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in('public','jioflow_private') and p.prokind='f' and p.proname in
 ('jf_agent_page78','jf_selection_rls74','jf_selection_staff74','jf_workspace_page_rls73','jf_workspace_page_staff73','jf_workspace_page','jf_workspace_page_fast','jf_latest_orders112','jf_followup_filter_options')
 loop execute format('alter function %s set plan_cache_mode = force_custom_plan',f.oid::regprocedure);end loop;
end $plans$;

-- Aggregate historical option columns together in one pass.
create or replace function public.jf_followup_filter_options(target_shop uuid)
returns jsonb language plpgsql stable security definer set search_path='' set plan_cache_mode=force_custom_plan as $$
declare staff boolean;mid uuid;result jsonb;begin
 staff:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);mid:=jioflow_private.agent_member(target_shop);
 if not staff and mid is null then raise exception 'Follow-up access required.' using errcode='42501';end if;
 with customers as materialized(select id from public.jf_customers where shop_id=target_shop and archived_at is null and (staff or assigned_membership_id=mid)),
 valueset as(select trim(h.payload->>'source') source,trim(h.payload->>'status') status,h.payload->>'tag' tag1,h.payload->>'tag2' tag2,h.payload->>'tag3' tag3,trim(h.payload->>'sku') sku from jioflow_private.jf_history_summary117 h join customers c on c.id=h.customer_id where h.shop_id=target_shop),
 opts as(select
coalesce(jsonb_agg(distinct sku order by sku) filter(where nullif(sku,'') is not null),'[]'::jsonb) skus,
coalesce(jsonb_agg(distinct status order by status) filter(where nullif(status,'') is not null),'[]'::jsonb) imported_statuses,
coalesce(jsonb_agg(distinct tag1 order by tag1) filter(where nullif(tag1,'') is not null),'[]'::jsonb) tags,
coalesce(jsonb_agg(distinct tag2 order by tag2) filter(where nullif(tag2,'') is not null),'[]'::jsonb) tags2,
coalesce(jsonb_agg(distinct tag3 order by tag3) filter(where nullif(tag3,'') is not null),'[]'::jsonb) tags3,
coalesce(jsonb_agg(distinct source order by source) filter(where nullif(source,'') is not null),'[]'::jsonb) sources from valueset),
 states as(select coalesce(jsonb_agg(distinct f.customer_status130 order by f.customer_status130) filter(where nullif(f.customer_status130,'') is not null),'[]'::jsonb) customer_statuses,
 coalesce(jsonb_agg(distinct f.call_status130 order by f.call_status130) filter(where f.call_status130 is not null),'[]'::jsonb) call_statuses
 from public.jf_followups f join customers c on c.id=f.customer_id where f.shop_id=target_shop),
 sources as(select jsonb_array_elements_text(o.sources) v from opts o union select trim(z.source) from public.jf_orders z join customers c on c.id=z.customer_id where z.shop_id=target_shop and z.archived_at is null)
 select to_jsonb(o)||to_jsonb(t)||jsonb_build_object('sources',coalesce((select jsonb_agg(v order by v) from sources where nullif(v,'') is not null),'[]'::jsonb)) into result from opts o cross join states t;
 return result;
end $$;
revoke all on function public.jf_followup_filter_options(uuid) from public,anon;
grant execute on function public.jf_followup_filter_options(uuid) to authenticated;

-- Support scoped list joins and page-only note/payment/product projections.
create index if not exists jf_customers_scope149 on public.jf_customers(shop_id,assigned_membership_id,id) where archived_at is null;
create index if not exists jf_orders_customer149 on public.jf_orders(shop_id,customer_id,created_at desc,id) where archived_at is null;
create index if not exists jf_notes_customer149 on public.jf_notes(shop_id,customer_id,created_at desc,id desc);
create index if not exists jf_payments_order149 on public.jf_payments(shop_id,order_id) where status in('pending','verified');
create index if not exists jf_items_order149 on public.jf_order_items(shop_id,order_id);
analyze public.jf_customers;
analyze public.jf_followups;
analyze public.jf_orders;
analyze public.jf_notes;
analyze public.jf_payments;
analyze public.jf_order_items;
analyze jioflow_private.jf_history_summary117;
analyze jioflow_private.jf_latest_history117;
commit;
