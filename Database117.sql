begin;
-- Private, persisted parsed import metadata. Not exposed through the public API.
create table if not exists jioflow_private.jf_history_summary117(
 history_id uuid primary key,shop_id uuid not null,customer_id uuid not null,
 order_date date,updated_at timestamptz,payload jsonb not null
);
revoke all on jioflow_private.jf_history_summary117 from public,anon,authenticated;
create index if not exists jf_history_summary117_latest on jioflow_private.jf_history_summary117(shop_id,customer_id,order_date desc nulls last,updated_at desc,history_id desc);
create or replace function jioflow_private.jf_history_payload117(details jsonb)
returns jsonb language sql immutable set search_path='' as $$
 select jsonb_build_object('total',details->>'total','advance',details->>'advance','status',public.jf_import_filter_value(details,'status'),'source',public.jf_import_filter_value(details,'source'),'sku',public.jf_import_filter_value(details,'sku'),'tag',public.jf_template_tag81(details,'custom_tag'),'tag2',public.jf_template_tag81(details,'custom_tag_2'),'tag3',public.jf_template_tag81(details,'custom_tag_3'),'imported',true)
$$;
revoke all on function jioflow_private.jf_history_payload117(jsonb) from public,anon,authenticated;
create table if not exists jioflow_private.jf_latest_history117(
 shop_id uuid not null,customer_id uuid not null,history_id uuid not null,order_date date,updated_at timestamptz,payload jsonb not null,primary key(shop_id,customer_id)
);
revoke all on jioflow_private.jf_latest_history117 from public,anon,authenticated;
create index if not exists jf_latest_history117_date on jioflow_private.jf_latest_history117(shop_id,order_date,customer_id);
create or replace function jioflow_private.jf_refresh_latest117(s uuid,c uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 perform pg_advisory_xact_lock(hashtextextended(s::text||c::text,117));
 delete from jioflow_private.jf_latest_history117 where shop_id=s and customer_id=c;
 insert into jioflow_private.jf_latest_history117 select shop_id,customer_id,history_id,order_date,updated_at,payload from jioflow_private.jf_history_summary117 where shop_id=s and customer_id=c order by order_date desc nulls last,updated_at desc,history_id desc limit 1;
end $$;
revoke all on function jioflow_private.jf_refresh_latest117(uuid,uuid) from public,anon,authenticated;
create or replace function jioflow_private.jf_sync_history117()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' then delete from jioflow_private.jf_history_summary117 where history_id=old.id;perform jioflow_private.jf_refresh_latest117(old.shop_id,old.customer_id);return old;end if;
 insert into jioflow_private.jf_history_summary117 values(new.id,new.shop_id,new.customer_id,new.import_order_date102,new.updated_at,jioflow_private.jf_history_payload117(new.details))
 on conflict(history_id) do update set shop_id=excluded.shop_id,customer_id=excluded.customer_id,order_date=excluded.order_date,updated_at=excluded.updated_at,payload=excluded.payload;
 perform jioflow_private.jf_refresh_latest117(new.shop_id,new.customer_id);
 if tg_op='UPDATE' and (old.shop_id,old.customer_id) is distinct from (new.shop_id,new.customer_id) then perform jioflow_private.jf_refresh_latest117(old.shop_id,old.customer_id);end if;
 return new;
end $$;
revoke all on function jioflow_private.jf_sync_history117() from public,anon,authenticated;
drop trigger if exists jf_history_summary117 on public.jf_order_history;
create trigger jf_history_summary117 after insert or update or delete on public.jf_order_history for each row execute function jioflow_private.jf_sync_history117();
insert into jioflow_private.jf_history_summary117
 select h.id,h.shop_id,h.customer_id,h.import_order_date102,h.updated_at,jioflow_private.jf_history_payload117(h.details) from public.jf_order_history h
 on conflict(history_id) do update set shop_id=excluded.shop_id,customer_id=excluded.customer_id,order_date=excluded.order_date,updated_at=excluded.updated_at,payload=excluded.payload;
insert into jioflow_private.jf_latest_history117
 select distinct on(shop_id,customer_id) shop_id,customer_id,history_id,order_date,updated_at,payload from jioflow_private.jf_history_summary117 order by shop_id,customer_id,order_date desc nulls last,updated_at desc,history_id desc
 on conflict(shop_id,customer_id) do update set history_id=excluded.history_id,order_date=excluded.order_date,updated_at=excluded.updated_at,payload=excluded.payload;
-- Replace only the imported branch of the existing guarded latest-order reader.
do $patch$
declare d text;start_at integer;end_at integer;
begin
 d:=pg_get_functiondef('jioflow_private.jf_latest_orders112(uuid)'::regprocedure);
 start_at:=position(' jsonb_build_object(''total'',h.details' in d);
 end_at:=position(' else jsonb_build_object(' in d);
 if start_at>0 and end_at>start_at then
 d:=substring(d from 1 for start_at-1)||' h.payload'||substring(d from end_at);
 d:=replace(d,'select h.customer_id cid,h.import_order_date102 d,h.updated_at t,h.id,true imported','select h.customer_id cid,h.order_date d,h.updated_at t,h.history_id id,true imported');
 d:=replace(d,'from public.jf_order_history h join public.jf_customers','from jioflow_private.jf_latest_history117 h join public.jf_customers');
 d:=replace(d,'left join public.jf_order_history h on k.imported and h.shop_id=target_shop and h.id=k.id','left join jioflow_private.jf_history_summary117 h on k.imported and h.shop_id=target_shop and h.history_id=k.id');
 execute d;
 elsif position('jf_history_summary117' in d)=0 then raise exception 'Apply Database116.sql before Database117.sql.';
 end if;
end $patch$;
analyze jioflow_private.jf_history_summary117;
analyze jioflow_private.jf_latest_history117;
commit;
