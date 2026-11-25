begin;
-- Choose one row per customer before decoding CSV metadata or aggregating product/payment data.
create or replace function jioflow_private.jf_latest_orders112(target_shop uuid)
returns table(customer_id uuid,order_date date,data jsonb)
language plpgsql stable security definer set search_path='' as $latest$
declare staff112 boolean;agent112 uuid;
begin
 staff112:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);agent112:=jioflow_private.agent_member(target_shop);
 if not staff112 and agent112 is null then raise exception 'Workspace access required.' using errcode='42501';end if;
 return query with chosen as materialized (
 select distinct on(m.cid) m.* from (
 select h.customer_id cid,h.import_order_date102 d,h.updated_at t,h.id,true imported
 from public.jf_order_history h join public.jf_customers c on c.shop_id=h.shop_id and c.id=h.customer_id where h.shop_id=target_shop and c.archived_at is null and (staff112 or c.assigned_membership_id=agent112)
 union all select z.customer_id,(z.created_at at time zone 'Asia/Dhaka')::date,z.created_at,z.id,false
 from public.jf_orders z join public.jf_customers c on c.shop_id=z.shop_id and c.id=z.customer_id where z.shop_id=target_shop and z.archived_at is null and c.archived_at is null and (staff112 or c.assigned_membership_id=agent112) and (staff112 or z.assigned_membership_id=agent112 or z.entered_by=auth.uid())
 ) m order by m.cid,m.d desc nulls last,m.t desc,m.id desc
 ) select k.cid,k.d,case when k.imported then
 jsonb_build_object('total',h.details->>'total','advance',h.details->>'advance','status',public.jf_import_filter_value(h.details,'status'),'source',public.jf_import_filter_value(h.details,'source'),'sku',public.jf_import_filter_value(h.details,'sku'),'tag',public.jf_template_tag81(h.details,'custom_tag'),'tag2',public.jf_template_tag81(h.details,'custom_tag_2'),'tag3',public.jf_template_tag81(h.details,'custom_tag_3'),'imported',true)
 else jsonb_build_object('total',z.total,'advance',(select coalesce(sum(p.amount),0) from public.jf_payments p where p.shop_id=z.shop_id and p.order_id=z.id and p.status in('pending','verified')),'status',z.status,'source',z.source,'sku',(select string_agg(p.sku,' ') from public.jf_order_items i join public.jf_products p on p.shop_id=i.shop_id and p.id=i.product_id where i.shop_id=z.shop_id and i.order_id=z.id),'imported',false) end
 from chosen k left join public.jf_order_history h on k.imported and h.shop_id=target_shop and h.id=k.id left join public.jf_orders z on not k.imported and z.shop_id=target_shop and z.id=k.id;
end $latest$;
-- Both projections previously scanned/decoded all purchase histories independently.
-- Reuse the latest-status materialization for the date/amount filter materialization.
do $patch$
declare fn record;d text;body text;
begin
 select prosrc into body from pg_proc where oid='jioflow_private.jf_matching_orders102(uuid,jsonb)'::regprocedure;
 body:=regexp_replace(body,';[[:space:]]*$','','g');
 body:=replace(body,'from jioflow_private.jf_latest_orders112(target_shop) l','from latest116 l');
 for fn in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname like 'jf_%' and p.prokind='f' loop
 d:=pg_get_functiondef(fn.oid);
 if position('latest103 as materialized(select customer_id,data->>''status'' as order_status,data->>''sku'' as latest_sku from jioflow_private.jf_latest_orders112(target_shop)),matched102 as materialized(select * from jioflow_private.jf_matching_orders102(target_shop,filters))' in d)>0 then
 d:=replace(d,'latest103 as materialized(select customer_id,data->>''status'' as order_status,data->>''sku'' as latest_sku from jioflow_private.jf_latest_orders112(target_shop)),matched102 as materialized(select * from jioflow_private.jf_matching_orders102(target_shop,filters))','latest116 as materialized(select * from jioflow_private.jf_latest_orders112(target_shop)),latest103 as materialized(select customer_id,data->>''status'' as order_status,data->>''sku'' as latest_sku from latest116),matched102(customer_id,order_date,amount) as materialized('||body||')');execute d;
 end if;
 end loop;
end $patch$;
analyze public.jf_order_history;
analyze public.jf_customers;
analyze public.jf_orders;
commit;
