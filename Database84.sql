begin;
create or replace function public.jf_followup_filter_options(target_shop uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare staff boolean;mid uuid;result jsonb;begin
 staff:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);mid:=jioflow_private.agent_member(target_shop);
 if not staff and mid is null then raise exception 'Follow-up access required.' using errcode='42501';end if;
 with customers as materialized(select id,source,workflow_label from public.jf_customers where shop_id=target_shop and archived_at is null and (staff or assigned_membership_id=mid)),
 h as materialized(select h.details from public.jf_order_history h join customers c on c.id=h.customer_id where h.shop_id=target_shop),
 valueset as materialized(select trim(public.jf_import_filter_value(details,'source')) source,trim(public.jf_import_filter_value(details,'status')) status,public.jf_template_tag81(details,'custom_tag') tag1,public.jf_template_tag81(details,'custom_tag_2') tag2,public.jf_template_tag81(details,'custom_tag_3') tag3 from h),
 sources as(select source v from valueset union select trim(o.source) from public.jf_orders o join customers c on c.id=o.customer_id where o.shop_id=target_shop and o.archived_at is null),
 customer_states as(select trim(workflow_label) v from customers union select trim(f.status) from public.jf_followups f join customers c on c.id=f.customer_id where f.shop_id=target_shop union select trim(f.call_outcome) from public.jf_followups f join customers c on c.id=f.customer_id where f.shop_id=target_shop),
 call_states as(select distinct coalesce(nullif(trim(f.call_outcome),''),'not_attempted') v from customers c left join public.jf_followups f on f.customer_id=c.id and f.shop_id=target_shop)
 select jsonb_build_object('customer_statuses',coalesce((select jsonb_agg(v order by v) from customer_states where nullif(v,'') is not null),'[]'),'call_statuses',coalesce((select jsonb_agg(v order by v) from call_states),'[]'),'sources',coalesce((select jsonb_agg(v order by v) from sources where nullif(v,'') is not null),'[]'),
 'imported_statuses',coalesce((select jsonb_agg(v order by v) from(select distinct status v from valueset where nullif(status,'') is not null)t),'[]'),
 'tags',coalesce((select jsonb_agg(v order by v) from(select distinct tag1 v from valueset where nullif(tag1,'') is not null)t),'[]'),
 'tags2',coalesce((select jsonb_agg(v order by v) from(select distinct tag2 v from valueset where nullif(tag2,'') is not null)t),'[]'),
 'tags3',coalesce((select jsonb_agg(v order by v) from(select distinct tag3 v from valueset where nullif(tag3,'') is not null)t),'[]')) into result;
 return result;
end $$;
revoke all on function public.jf_followup_filter_options(uuid) from public,anon;
grant execute on function public.jf_followup_filter_options(uuid) to authenticated;
do $patch$
declare r record;d text;
begin
 for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname in('jf_workspace_page_rls73','jf_workspace_page_staff73','jf_agent_page78','jf_selection_rls74','jf_selection_staff74','jf_followup_amount83') loop
 d:=pg_get_functiondef(r.oid);
 d:=replace(d,'lower(h.details->>''status'')','lower(trim(public.jf_import_filter_value(h.details,''status'')))');
 d:=replace(d,'lower(coalesce(nullif(public.jf_import_filter_value(h.details,''source''),''''),c.source))','lower(trim(public.jf_import_filter_value(h.details,''source'')))');
 d:=replace(d,'lower(c.workflow_label)','lower(trim(c.workflow_label))');
 d:=replace(d,'f.status=filters->>''af_customer_status''','lower(trim(f.status))=lower(filters->>''af_customer_status'')');
 d:=replace(d,'lower(z.source)','lower(trim(z.source))');
 execute d;
 end loop;
end $patch$;
insert into public.jf_schema_versions(version) values('057_actual_followup_options') on conflict do nothing;
commit;
