begin;
-- Cache parsed CSV date once on write, rather than parse original JSON for every filter.
alter table public.jf_order_history add column if not exists import_order_date102 date;
create or replace function public.jf_history_date102() returns trigger
language plpgsql security invoker set search_path='' as $$
begin new.import_order_date102:=public.jf_import_date100(new.details);return new;end $$;
revoke all on function public.jf_history_date102() from public,anon,authenticated;
drop trigger if exists jf_history_date102 on public.jf_order_history;
create trigger jf_history_date102 before insert or update on public.jf_order_history
for each row execute function public.jf_history_date102();
update public.jf_order_history set import_order_date102=public.jf_import_date100(details)
where import_order_date102 is distinct from public.jf_import_date100(details);
create index if not exists jf_history_customer_date102 on public.jf_order_history(shop_id,customer_id,import_order_date102,id);
create index if not exists jf_history_date_customer102 on public.jf_order_history(shop_id,import_order_date102,customer_id);
create or replace function jioflow_private.jf_matching_orders102(target_shop uuid,filters jsonb)
returns table(customer_id uuid,order_date date,amount numeric)
language plpgsql stable security definer set search_path='' as $batch$
declare staff102 boolean;agent102 uuid;
begin
 staff102:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);
 agent102:=jioflow_private.agent_member(target_shop);
 if not staff102 and agent102 is null then raise exception 'Workspace access required.' using errcode='42501';end if;
 return query select distinct on(m.cid) m.cid,m.order_date,m.amount from (
 select public.jf_order_amount_value(h.details->>case when filters->>'af_payment_basis'='advance' then 'advance' else 'total' end) amount,h.import_order_date102 order_date,h.id match_id,h.customer_id cid
 from public.jf_order_history h join public.jf_customers c on c.shop_id=h.shop_id and c.id=h.customer_id where h.shop_id=target_shop and c.archived_at is null and (staff102 or c.assigned_membership_id=agent102)
     and (nullif(filters->>'af_order_date','') is null or h.import_order_date102=(filters->>'af_order_date')::date)
     and (nullif(filters->>'af_order_from','') is null or h.import_order_date102>=(filters->>'af_order_from')::date)
     and (nullif(filters->>'af_order_to','') is null or h.import_order_date102<=(filters->>'af_order_to')::date)
     and (nullif(filters->>'af_imported_status','') is null or lower(trim(public.jf_import_filter_value(h.details,'status')))=lower(filters->>'af_imported_status'))
     and (nullif(filters->>'af_sku','') is null or public.jf_import_filter_value(h.details,'sku') ilike '%'||(filters->>'af_sku')||'%')
     and (nullif(filters->>'af_source','') is null or lower(trim(public.jf_import_filter_value(h.details,'source')))=lower(filters->>'af_source'))
     and (nullif(filters->>'af_tag','') is null or public.jf_template_tag81(h.details,'custom_tag')=filters->>'af_tag')
     and (nullif(filters->>'af_tag2','') is null or public.jf_template_tag81(h.details,'custom_tag_2')=filters->>'af_tag2')
     and (nullif(filters->>'af_tag3','') is null or public.jf_template_tag81(h.details,'custom_tag_3')=filters->>'af_tag3')
     and public.jf_payment_filter_match(h.details->>case when filters->>'af_payment_basis'='advance' then 'advance' else 'total' end,filters->>'af_payment_ranges')
 union all select case when filters->>'af_payment_basis'='advance' then (select coalesce(sum(p.amount),0) from public.jf_payments p where p.shop_id=z.shop_id and p.order_id=z.id and p.status in('pending','verified')) else z.total end,(z.created_at at time zone 'Asia/Dhaka')::date,z.id,z.customer_id from public.jf_orders z join public.jf_customers c on c.shop_id=z.shop_id and c.id=z.customer_id where z.shop_id=target_shop and c.archived_at is null and (staff102 or c.assigned_membership_id=agent102) and z.archived_at is null
 and (staff102 or z.assigned_membership_id=agent102 or (agent102 is not null and z.entered_by=auth.uid()))
       and (nullif(filters->>'af_order_date','') is null or (z.created_at at time zone 'Asia/Dhaka')::date=(filters->>'af_order_date')::date)
       and (nullif(filters->>'af_order_from','') is null or (z.created_at at time zone 'Asia/Dhaka')::date>=(filters->>'af_order_from')::date)
       and (nullif(filters->>'af_order_to','') is null or (z.created_at at time zone 'Asia/Dhaka')::date<=(filters->>'af_order_to')::date)
       and (nullif(filters->>'af_source','') is null or lower(trim(z.source))=lower(filters->>'af_source'))
       and public.jf_payment_filter_match(case when filters->>'af_payment_basis'='advance' then (select coalesce(sum(p.amount),0)::text from public.jf_payments p where p.shop_id=z.shop_id and p.order_id=z.id and p.status in('pending','verified')) else z.total::text end,filters->>'af_payment_ranges')
       and (nullif(filters->>'af_sku','') is null or exists(select 1 from public.jf_order_items i join public.jf_products p on p.shop_id=i.shop_id and p.id=i.product_id where i.shop_id=z.shop_id and i.order_id=z.id and p.sku ilike '%'||(filters->>'af_sku')||'%'))
 and nullif(filters->>'af_imported_status','') is null and nullif(filters->>'af_tag','') is null and nullif(filters->>'af_tag2','') is null and nullif(filters->>'af_tag3','') is null
 ) m order by m.cid,m.order_date desc nulls last,m.match_id desc;
end $batch$;
revoke all on function jioflow_private.jf_matching_orders102(uuid,jsonb) from public,anon;
grant execute on function jioflow_private.jf_matching_orders102(uuid,jsonb) to authenticated;

-- Preserve every existing authorization guard; only replace parsing and customer page projection.
do $patch$
declare r record;d text;old text;pos integer;lastpos integer;
begin
 for r in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in('public','jioflow_private') and p.prokind='f' and p.proname like 'jf_%'
 and p.proname not in('jf_import_date100','jf_history_date102','jf_matching_orders102') loop
 d:=pg_get_functiondef(r.oid);
 d:=replace(d,'public.jf_import_date100(h.details)','h.import_order_date102');
 if r.proname='jf_followup_order100' then
 d:=replace(d,'lower(h.details->>''status'')','lower(trim(public.jf_import_filter_value(h.details,''status'')))');
 d:=replace(d,'lower(coalesce(nullif(public.jf_import_filter_value(h.details,''source''),''''),c.source))','lower(trim(public.jf_import_filter_value(h.details,''source'')))');
 d:=replace(d,'lower(z.source)','lower(trim(z.source))');
 end if;
 if r.proname not like 'jf_selection_%' and position('from(select * from c order by updated_at desc,id limit' in d)>0 then
 -- Match orders once per request, avoiding thousands of guarded per-customer calls.
 d:=replace(d,'with base as materialized(', 'with matched102 as materialized(select * from jioflow_private.jf_matching_orders102(target_shop,filters)),base as materialized(');
 d:=replace(d,'from(select * from c order by updated_at desc,id limit',
 'from(select c.*,jsonb_build_object(''order_date'',m.order_date,''amount'',m.amount) as _order102 from c left join matched102 m on m.customer_id=c.id order by m.order_date asc nulls last,c.id limit');
 d:=replace(d,'to_jsonb(p)||case when coalesce(filters->>''_fast'','''')=''true'' then ''{}''::jsonb else',
 '(to_jsonb(p)-''_order102'')||jsonb_build_object(''order_date'',p._order102->>''order_date'',''order_amount'',p._order102->''amount'')||case when coalesce(filters->>''_fast'','''')=''true'' then ''{}''::jsonb else');
 d:=replace(d,'public.jf_followup_order100(target_shop,p.id,filters)->>''order_date''','p._order102->>''order_date''');
 pos:=position('''order_amount'',case when' in d);
 if pos>0 then
 lastpos:=position(',''order_count''' in substring(d from pos));
 if lastpos=0 then raise exception 'Missing order projection boundary: %',r.proname;end if;
 d:=substring(d from 1 for pos-1)||'''order_amount'',p._order102->''amount'''||substring(d from pos+lastpos-1);
 end if;
 end if;
 if d<>pg_get_functiondef(r.oid) then execute d;end if;
 end loop;
end $patch$;
analyze public.jf_order_history;
commit;
