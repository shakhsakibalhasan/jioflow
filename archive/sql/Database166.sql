-- Apply after Database162.sql. Transactional and safe to rerun.
begin;
CREATE OR REPLACE FUNCTION jioflow_private.jf_latest_orders166(target_shop uuid, target_agent uuid default null)
 RETURNS TABLE(customer_id uuid, order_date date, data jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
 SET plan_cache_mode TO 'force_custom_plan'
AS $function$
declare staff112 boolean;agent112 uuid;
begin
 staff112:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);agent112:=jioflow_private.agent_member(target_shop);
 if not staff112 and agent112 is null then raise exception 'Workspace access required.' using errcode='42501';end if;
 return query with chosen as materialized (
 select distinct on(m.cid) m.* from (
 select h.customer_id cid,h.order_date d,h.updated_at t,h.history_id id,true imported
 from jioflow_private.jf_latest_history117 h join public.jf_customers c on c.shop_id=h.shop_id and c.id=h.customer_id where h.shop_id=target_shop and c.archived_at is null and (target_agent is null or c.assigned_membership_id=target_agent) and (staff112 or c.assigned_membership_id=agent112)
 union all select z.customer_id,(z.created_at at time zone 'Asia/Dhaka')::date,z.created_at,z.id,false
 from public.jf_orders z join public.jf_customers c on c.shop_id=z.shop_id and c.id=z.customer_id where z.shop_id=target_shop and z.archived_at is null and c.archived_at is null and (target_agent is null or c.assigned_membership_id=target_agent) and (staff112 or c.assigned_membership_id=agent112) and (staff112 or z.assigned_membership_id=agent112 or z.entered_by=auth.uid())
 ) m order by m.cid,m.d desc nulls last,m.t desc,m.id desc
 ) select k.cid,k.d,case when k.imported then
 h.payload else jsonb_build_object('total',z.total,'advance',(select coalesce(sum(p.amount),0) from public.jf_payments p where p.shop_id=z.shop_id and p.order_id=z.id and p.status in('pending','verified')),'status',z.status,'source',z.source,'sku',(select string_agg(p.sku,' ') from public.jf_order_items i join public.jf_products p on p.shop_id=i.shop_id and p.id=i.product_id where i.shop_id=z.shop_id and i.order_id=z.id),'imported',false) end
 from chosen k left join jioflow_private.jf_history_summary117 h on k.imported and h.shop_id=target_shop and h.history_id=k.id left join public.jf_orders z on not k.imported and z.shop_id=target_shop and z.id=k.id;
end $function$
;
revoke all on function jioflow_private.jf_latest_orders166(uuid,uuid) from public,anon,authenticated;

DO $patch$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('jioflow_private.jf_workspace_page_staff73(uuid,text,jsonb,integer)'::regprocedure) INTO d;
 IF position('jioflow_private.jf_latest_orders112(target_shop)' in d)>0 THEN
 d:=replace(d,'jioflow_private.jf_latest_orders112(target_shop)','jioflow_private.jf_latest_orders166(target_shop,agent_id)');EXECUTE d;
 ELSIF position('jioflow_private.jf_latest_orders166(target_shop,agent_id)' in d)=0 THEN
 RAISE EXCEPTION 'Unsupported workspace version; no changes applied.';
 END IF;
END $patch$;
CREATE OR REPLACE FUNCTION public.jf_finance_totals(target_shop uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
 if not jioflow_private.has_permission(target_shop,'profit') then raise exception 'Finance access denied.' using errcode='42501';end if;
 with item_costs as materialized(
 select i.order_id,coalesce(sum(i.quantity*pc.unit_cost) filter(where pc.unit_cost is not null),0) known_cost,
 coalesce(sum(i.quantity*i.unit_price) filter(where pc.unit_cost is not null),0) known_sales,
 coalesce(sum(i.quantity*i.unit_price),0) all_sales,
 count(*) filter(where pc.unit_cost is null) missing
 from public.jf_order_items i left join public.jf_product_costs pc on pc.shop_id=i.shop_id and pc.product_id=i.product_id
 where i.shop_id=target_shop group by i.order_id
 ),o as(select o.*,coalesce(f.product_cost,ic.known_cost,0) product_cost,
 case when f.product_cost is not null then 1::numeric when ic.all_sales>0 then least(1::numeric,greatest(0::numeric,ic.known_sales/ic.all_sales)) else 0::numeric end known_ratio,
 (f.product_cost is null and coalesce(ic.missing,1)>0) missing_cost,
 coalesce(f.courier_charge,o.delivery_charge)+coalesce(f.cod_fee,0)+coalesce(f.packaging_cost,0)+coalesce(f.return_cost,0)+coalesce(f.other_cost,0) fees,
 case when o.status='delivered' then greatest(0,coalesce(f.cod_expected,(select (s.request_payload->>'cod_amount')::numeric from public.jf_shipments s where s.shop_id=o.shop_id and s.order_id=o.id and s.courier='steadfast' and s.consignment_id is not null order by s.created_at desc limit 1),o.total-coalesce((select sum(amount) from public.jf_payments p where p.shop_id=target_shop and p.order_id=o.id and p.status='verified'),0))-coalesce(f.cod_received,0)) else 0 end cod_pending
 from public.jf_orders o left join item_costs ic on ic.order_id=o.id left join public.jf_order_finance f on f.shop_id=o.shop_id and f.order_id=o.id where o.shop_id=target_shop and o.archived_at is null and o.status not in('draft','cancelled'))
 select jsonb_build_object('revenue',coalesce(sum(total),0),'product_cost',coalesce(sum(product_cost),0),'fees',coalesce(sum(fees),0),'profit',coalesce(sum((total-fees)*known_ratio-product_cost),0),'cod_pending',coalesce(sum(cod_pending),0),'missing_cost_orders',count(*) filter(where missing_cost),'agents',(select coalesce(jsonb_object_agg(t.member,t.profit),'{}') from(select coalesce(assigned_membership_id::text,'unassigned') member,sum((total-fees)*known_ratio-product_cost) profit from o group by assigned_membership_id)t)) into result from o;
 return result;
end $function$
;
commit;
