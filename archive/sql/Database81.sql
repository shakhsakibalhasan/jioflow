begin;
-- Template tags are independent of assignment/reassignment labels.
create or replace function public.jf_template_tag81(data jsonb,field text) returns text language sql immutable security invoker set search_path='' as $$
 select trim(coalesce(nullif(data->>field,''),(select x->>'value' from jsonb_array_elements(case when jsonb_typeof(data->'original_columns')='array' then data->'original_columns' else '[]'::jsonb end)x
 where regexp_replace(lower(x->>'column'),'[^a-z0-9]','','g')=any(case field when 'custom_tag' then array['customtag','customtags','customtag1','customtags1','tag1'] when 'custom_tag_2' then array['customtag2','customtags2','tag2'] when 'custom_tag_3' then array['customtag3','customtags3','tag3'] else array[]::text[] end) limit 1),''));
$$;
revoke all on function public.jf_template_tag81(jsonb,text) from public,anon;
grant execute on function public.jf_template_tag81(jsonb,text) to authenticated;
create or replace function public.jf_followup_filter_options(target_shop uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare staff boolean;mid uuid;result jsonb;begin
 staff:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);mid:=jioflow_private.agent_member(target_shop);
 if not staff and mid is null then raise exception 'Follow-up access required.' using errcode='42501';end if;
 with customers as materialized(select id,source from public.jf_customers where shop_id=target_shop and archived_at is null and (staff or assigned_membership_id=mid)),
 h as materialized(select h.details from public.jf_order_history h join customers c on c.id=h.customer_id where h.shop_id=target_shop),
 valueset as materialized(select trim(public.jf_import_filter_value(details,'source')) source,trim(details->>'status') status,public.jf_template_tag81(details,'custom_tag') tag1,public.jf_template_tag81(details,'custom_tag_2') tag2,public.jf_template_tag81(details,'custom_tag_3') tag3 from h),
 sources as(select trim(source) v from customers union select source from valueset)
 select jsonb_build_object('sources',coalesce((select jsonb_agg(v order by v) from sources where nullif(v,'') is not null),'[]'),
 'imported_statuses',coalesce((select jsonb_agg(v order by v) from(select distinct status v from valueset where nullif(status,'') is not null)t),'[]'),
 'tags',coalesce((select jsonb_agg(v order by v) from(select distinct tag1 v from valueset where nullif(tag1,'') is not null)t),'[]'),
 'tags2',coalesce((select jsonb_agg(v order by v) from(select distinct tag2 v from valueset where nullif(tag2,'') is not null)t),'[]'),
 'tags3',coalesce((select jsonb_agg(v order by v) from(select distinct tag3 v from valueset where nullif(tag3,'') is not null)t),'[]')) into result;
 return result;
end $$;
revoke all on function public.jf_followup_filter_options(uuid) from public,anon;
grant execute on function public.jf_followup_filter_options(uuid) to authenticated;
-- Update every read/selection path, preserving its existing security guard.
do $patch$ declare f record;body text;k text;begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname in('jf_workspace_page','jf_workspace_page_rls73','jf_workspace_page_staff73','jf_agent_page78','jf_selection_rls74','jf_selection_staff74') loop
 body:=pg_get_functiondef(f.oid);
 body:=replace(body,'c.unassignment_tag=filters->>''af_tag'' or ','');
 body:=replace(body,'coalesce(nullif(public.jf_import_filter_value(h.details,''custom_tag''),''''),h.details->>''reference_tag'')','public.jf_template_tag81(h.details,''custom_tag'')');
 body:=replace(body,'(nullif(filters->>''af_tag'','''') is null or c.unassignment_tag=filters->>''af_tag'')','(nullif(filters->>''af_tag'','''') is null)');
 foreach k in array array['custom_tag','custom_tag_2','custom_tag_3'] loop body:=replace(body,format('public.jf_import_filter_value(h.details,%L)',k),format('public.jf_template_tag81(h.details,%L)',k));end loop;
 execute body;
 end loop;
end $patch$;
insert into public.jf_schema_versions(version) values('055_template_filter_tags') on conflict do nothing;
commit;
