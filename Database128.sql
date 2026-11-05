begin;
create or replace function jioflow_private.jf_sku_match128(value text,selection text) returns boolean language plpgsql immutable set search_path='' as $$
begin
 if coalesce(selection,'')='' then return true;end if;
 if left(selection,12)='selected128:' then
 return exists(select 1 from jsonb_array_elements_text(substring(selection from 13)::jsonb) s(v) where lower(trim(value))=lower(trim(s.v)));
 end if;
 return value ilike '%'||selection||'%';
end $$;

create or replace function public.jf_followup_filter_options(target_shop uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare staff boolean;mid uuid;result jsonb;begin
 staff:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);mid:=jioflow_private.agent_member(target_shop);
 if not staff and mid is null then raise exception 'Follow-up access required.' using errcode='42501';end if;
 with customers as materialized(select id,source,workflow_label from public.jf_customers where shop_id=target_shop and archived_at is null and (staff or assigned_membership_id=mid)),
 valueset as materialized(select trim(h.payload->>'source') source,trim(h.payload->>'status') status,h.payload->>'tag' tag1,h.payload->>'tag2' tag2,h.payload->>'tag3' tag3,trim(h.payload->>'sku') sku from jioflow_private.jf_history_summary117 h join customers c on c.id=h.customer_id where h.shop_id=target_shop),
 sources as(select source v from valueset union select trim(o.source) from public.jf_orders o join customers c on c.id=o.customer_id where o.shop_id=target_shop and o.archived_at is null),
 customer_states as(select trim(workflow_label) v from customers union select trim(f.status) from public.jf_followups f join customers c on c.id=f.customer_id where f.shop_id=target_shop union select trim(f.call_outcome) from public.jf_followups f join customers c on c.id=f.customer_id where f.shop_id=target_shop),
 call_states as(select distinct coalesce(nullif(trim(f.call_outcome),''),'not_attempted') v from customers c left join public.jf_followups f on f.customer_id=c.id and f.shop_id=target_shop)
 select jsonb_build_object('skus',coalesce((select jsonb_agg(v order by v) from(select distinct sku v from valueset where nullif(sku,'') is not null)t),'[]'),'customer_statuses',coalesce((select jsonb_agg(v order by v) from customer_states where nullif(v,'') is not null),'[]'),'call_statuses',coalesce((select jsonb_agg(v order by v) from call_states),'[]'),'sources',coalesce((select jsonb_agg(v order by v) from sources where nullif(v,'') is not null),'[]'),
 'imported_statuses',coalesce((select jsonb_agg(v order by v) from(select distinct status v from valueset where nullif(status,'') is not null)t),'[]'),
 'tags',coalesce((select jsonb_agg(v order by v) from(select distinct tag1 v from valueset where nullif(tag1,'') is not null)t),'[]'),
 'tags2',coalesce((select jsonb_agg(v order by v) from(select distinct tag2 v from valueset where nullif(tag2,'') is not null)t),'[]'),
 'tags3',coalesce((select jsonb_agg(v order by v) from(select distinct tag3 v from valueset where nullif(tag3,'') is not null)t),'[]')) into result;
 return result;
end $$;
revoke all on function public.jf_followup_filter_options(uuid) from public,anon;
grant execute on function public.jf_followup_filter_options(uuid) to authenticated;

do $patch$
declare f record;d text;begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname like 'jf_%' and p.prokind='f' loop
 d:=pg_get_functiondef(f.oid);
 if position($old$l.data->>'sku' ilike '%'||(filters->>'af_sku')||'%'$old$ in d)>0 then
 d:=replace(d,$old$l.data->>'sku' ilike '%'||(filters->>'af_sku')||'%'$old$,$new$jioflow_private.jf_sku_match128(l.data->>'sku',filters->>'af_sku')$new$);execute d;
 end if;end loop;
end $patch$;
commit;
