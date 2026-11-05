begin;
create or replace function jioflow_private.jf_latest_orders112(target_shop uuid)
returns table(customer_id uuid,order_date date,data jsonb)
language plpgsql stable security definer set search_path='' as $latest$
declare staff112 boolean;agent112 uuid;
begin
 staff112:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);agent112:=jioflow_private.agent_member(target_shop);
 if not staff112 and agent112 is null then raise exception 'Workspace access required.' using errcode='42501';end if;
 return query select distinct on(m.cid) m.cid,m.d,m.payload from (
 select h.customer_id cid,h.import_order_date102 d,h.updated_at t,h.id,
 jsonb_build_object('total',h.details->>'total','advance',h.details->>'advance','status',public.jf_import_filter_value(h.details,'status'),'source',public.jf_import_filter_value(h.details,'source'),'sku',public.jf_import_filter_value(h.details,'sku'),'tag',public.jf_template_tag81(h.details,'custom_tag'),'tag2',public.jf_template_tag81(h.details,'custom_tag_2'),'tag3',public.jf_template_tag81(h.details,'custom_tag_3'),'imported',true) payload
 from public.jf_order_history h join public.jf_customers c on c.shop_id=h.shop_id and c.id=h.customer_id where h.shop_id=target_shop and c.archived_at is null and (staff112 or c.assigned_membership_id=agent112)
 union all select z.customer_id,(z.created_at at time zone 'Asia/Dhaka')::date,z.created_at,z.id,
 jsonb_build_object('total',z.total,'advance',(select coalesce(sum(p.amount),0) from public.jf_payments p where p.shop_id=z.shop_id and p.order_id=z.id and p.status in('pending','verified')),'status',z.status,'source',z.source,'sku',(select string_agg(p.sku,' ') from public.jf_order_items i join public.jf_products p on p.shop_id=i.shop_id and p.id=i.product_id where i.shop_id=z.shop_id and i.order_id=z.id),'imported',false)
 from public.jf_orders z join public.jf_customers c on c.shop_id=z.shop_id and c.id=z.customer_id where z.shop_id=target_shop and z.archived_at is null and c.archived_at is null and (staff112 or c.assigned_membership_id=agent112) and (staff112 or z.assigned_membership_id=agent112 or z.entered_by=auth.uid())
 ) m order by m.cid,m.d desc nulls last,m.t desc,m.id desc;
end $latest$;
revoke all on function jioflow_private.jf_latest_orders112(uuid) from public,anon;
grant execute on function jioflow_private.jf_latest_orders112(uuid) to authenticated;
create or replace function jioflow_private.jf_matching_orders102(target_shop uuid,filters jsonb)
returns table(customer_id uuid,order_date date,amount numeric)
language sql stable security invoker set search_path='' as $match$
 select l.customer_id,l.order_date,public.jf_order_amount_value(l.data->>case when filters->>'af_payment_basis'='advance' then 'advance' else 'total' end)
 from jioflow_private.jf_latest_orders112(target_shop) l
 where (nullif(filters->>'af_order_date','') is null or l.order_date=(filters->>'af_order_date')::date)
 and (nullif(filters->>'af_order_from','') is null or l.order_date>=(filters->>'af_order_from')::date)
 and (nullif(filters->>'af_order_to','') is null or l.order_date<=(filters->>'af_order_to')::date)
 and (nullif(filters->>'af_imported_status','') is null or l.data->>'imported'='true' and lower(trim(l.data->>'status'))=lower(filters->>'af_imported_status'))
 and (nullif(filters->>'af_source','') is null or lower(trim(l.data->>'source'))=lower(filters->>'af_source'))
 and (nullif(filters->>'af_sku','') is null or l.data->>'sku' ilike '%'||(filters->>'af_sku')||'%')
 and (nullif(filters->>'af_tag','') is null or l.data->>'tag'=filters->>'af_tag')
 and (nullif(filters->>'af_tag2','') is null or l.data->>'tag2'=filters->>'af_tag2')
 and (nullif(filters->>'af_tag3','') is null or l.data->>'tag3'=filters->>'af_tag3')
 and public.jf_payment_filter_match(l.data->>case when filters->>'af_payment_basis'='advance' then 'advance' else 'total' end,filters->>'af_payment_ranges');
$match$;
revoke all on function jioflow_private.jf_matching_orders102(uuid,jsonb) from public,anon;
grant execute on function jioflow_private.jf_matching_orders102(uuid,jsonb) to authenticated;
create or replace function jioflow_private.jf_latest_order_status103(target_shop uuid)
returns table(customer_id uuid,order_status text) language sql stable security invoker set search_path='' as $$
 select customer_id,nullif(trim(data->>'status'),'') from jioflow_private.jf_latest_orders112(target_shop);
$$;
do $patch$
declare r record;d text;a integer;b integer;relation text;
begin
 for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.prokind='f' and p.proname like 'jf_%' loop
 d:=pg_get_functiondef(r.oid);
 a:=position('and (not exists(select 1 from jsonb_each_text(filters) x where x.key in(''af_order_date''' in d);
 if a>0 then
 b:=position('and (coalesce(filters->>''source'','''')' in substring(d from a));
 if b=0 then raise exception 'Review customer filter boundaries before applying112';end if;
 if position('matched102 as materialized(' in d)>0 then relation:='matched102';
 else relation:='matched112';d:=replace(d,'with base as materialized(', 'with matched112 as materialized(select * from jioflow_private.jf_matching_orders102(target_shop,filters)),base as materialized(');
 a:=position('and (not exists(select 1 from jsonb_each_text(filters) x where x.key in(''af_order_date''' in d);b:=position('and (coalesce(filters->>''source'','''')' in substring(d from a));end if;
 d:=substring(d from 1 for a-1)||'and (not exists(select 1 from jsonb_each_text(filters) x where x.key in(''af_order_date'',''af_order_from'',''af_order_to'',''af_imported_status'',''af_sku'',''af_source'',''af_tag'',''af_tag2'',''af_tag3'',''af_payment_ranges'') and coalesce(x.value,'''')<>'''') or exists(select 1 from '||relation||' latest112 where latest112.customer_id=c.id)) '||substring(d from a+b-1);
 execute d;
 end if;
 end loop;
end $patch$;
commit;
