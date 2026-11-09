-- READ ONLY: compare affected customers' saved import status with the original
-- CSV status values and any newer native order. No records are changed.
select c.shop_id,c.phone,c.full_name,h.external_id,h.import_order_date102 order_date,
 h.updated_at import_updated_at,h.details->>'status' saved_status,
 (select jsonb_agg(x) from jsonb_array_elements(case when jsonb_typeof(h.details->'original_columns')='array' then h.details->'original_columns' else '[]'::jsonb end) x
 where regexp_replace(lower(x->>'column'),'[^a-z0-9]','','g') in('status','orderstatus','deliverystatus','courierstatus')) original_status_columns,
 (select jsonb_build_object('status',o.status,'created_at',o.created_at,'order_number',o.order_number) from public.jf_orders o where o.shop_id=c.shop_id and o.customer_id=c.id and o.archived_at is null order by o.created_at desc limit 1) newest_native_order
from public.jf_customers c join public.jf_order_history h on h.shop_id=c.shop_id and h.customer_id=c.id
where c.archived_at is null and c.phone in('+8801716678255','+8801982854505','+8801766124327','+8801714095765','+8801834559491','+8801500000000','+8801685093581','+8801910712212','+8801867709769','+8801877687311')
order by c.phone,h.import_order_date102 desc nulls last,h.updated_at desc;
