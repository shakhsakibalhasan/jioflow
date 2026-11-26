begin;
alter table public.jf_followups add column if not exists call_status130 text check(call_status130 in('connected','not_connected'));
alter table public.jf_followups add column if not exists customer_status130 text check(customer_status130 in('positive','intermediate','negative','irregular'));
create or replace function public.jf_followup_outcomes130(target_shop uuid,customer_id uuid,status_label text,callback_time timestamptz default null,note_text text default '',call_status text default null,customer_status text default null) returns uuid language plpgsql security definer set search_path='' as $$
declare fid uuid;begin
 if call_status is not null and call_status not in('connected','not_connected') or customer_status is not null and customer_status not in('positive','intermediate','negative','irregular') then raise exception 'Choose valid call and customer statuses.';end if;
 if status_label='Confirm' and (call_status is null or customer_status is null) then raise exception 'Call Status and Customer Status are required.';end if;
 -- Existing status function enforces session, shop, approved membership and customer visibility.
 fid:=public.jf_followup_status(target_shop,customer_id,status_label,callback_time,note_text);
 update public.jf_followups f set call_status130=call_status,customer_status130=customer_status,
 call_outcome=case when call_status='not_connected' then 'not_connected' when call_status='connected' then case when customer_status in('positive','intermediate','negative') then customer_status else 'connected' end else f.call_outcome end
 where f.id=fid and f.shop_id=target_shop;
 return fid;
end $$;
revoke all on function public.jf_followup_outcomes130(uuid,uuid,text,timestamptz,text,text,text) from public,anon;
grant execute on function public.jf_followup_outcomes130(uuid,uuid,text,timestamptz,text,text,text) to authenticated;
-- Separate classifications; legacy records derive only unambiguous values.
update public.jf_followups set call_status130=case when call_outcome in('connected','positive','negative','intermediate') then 'connected' when call_outcome in('not_connected','no_answer','busy') then 'not_connected' end where call_status130 is null;
update public.jf_followups set customer_status130=call_outcome where customer_status130 is null and call_outcome in('positive','intermediate','negative');
do $patch$
declare f record;d text;begin
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname like 'jf_%' and p.prokind='f' loop
 d:=pg_get_functiondef(f.oid);
 d:=regexp_replace(d,$re$and \(nullif\(filters->>'af_customer_status',''\) is null[^\n]*$re$,$new$and (nullif(filters->>'af_customer_status','') is null or f.customer_status130=lower(replace(filters->>'af_customer_status',' ','_')))$new$,'g');
 d:=regexp_replace(d,$re$and \(nullif\(filters->>'af_call_status',''\) is null[^\n]*$re$,$new$and (nullif(filters->>'af_call_status','') is null or f.call_status130=lower(replace(filters->>'af_call_status',' ','_')))$new$,'g');
 if d<>pg_get_functiondef(f.oid) then execute d;end if;
 end loop;
end $patch$;
create or replace function public.jf_followup_filter_options(target_shop uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare staff boolean;mid uuid;result jsonb;begin
 staff:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);mid:=jioflow_private.agent_member(target_shop);
 if not staff and mid is null then raise exception 'Follow-up access required.' using errcode='42501';end if;
 with customers as materialized(select id,source,workflow_label from public.jf_customers where shop_id=target_shop and archived_at is null and (staff or assigned_membership_id=mid)),
 valueset as materialized(select trim(h.payload->>'source') source,trim(h.payload->>'status') status,h.payload->>'tag' tag1,h.payload->>'tag2' tag2,h.payload->>'tag3' tag3,trim(h.payload->>'sku') sku from jioflow_private.jf_history_summary117 h join customers c on c.id=h.customer_id where h.shop_id=target_shop),
 sources as(select source v from valueset union select trim(o.source) from public.jf_orders o join customers c on c.id=o.customer_id where o.shop_id=target_shop and o.archived_at is null),
 customer_states as(select distinct f.customer_status130 v from public.jf_followups f join customers c on c.id=f.customer_id where f.shop_id=target_shop and f.customer_status130 is not null),
 call_states as(select distinct f.call_status130 v from public.jf_followups f join customers c on c.id=f.customer_id where f.shop_id=target_shop and f.call_status130 is not null)
 select jsonb_build_object('skus',coalesce((select jsonb_agg(v order by v) from(select distinct sku v from valueset where nullif(sku,'') is not null)t),'[]'),'customer_statuses',coalesce((select jsonb_agg(v order by v) from customer_states where nullif(v,'') is not null),'[]'),'call_statuses',coalesce((select jsonb_agg(v order by v) from call_states),'[]'),'sources',coalesce((select jsonb_agg(v order by v) from sources where nullif(v,'') is not null),'[]'),
 'imported_statuses',coalesce((select jsonb_agg(v order by v) from(select distinct status v from valueset where nullif(status,'') is not null)t),'[]'),
 'tags',coalesce((select jsonb_agg(v order by v) from(select distinct tag1 v from valueset where nullif(tag1,'') is not null)t),'[]'),
 'tags2',coalesce((select jsonb_agg(v order by v) from(select distinct tag2 v from valueset where nullif(tag2,'') is not null)t),'[]'),
 'tags3',coalesce((select jsonb_agg(v order by v) from(select distinct tag3 v from valueset where nullif(tag3,'') is not null)t),'[]')) into result;
 return result;
end $$;
revoke all on function public.jf_followup_filter_options(uuid) from public,anon;
grant execute on function public.jf_followup_filter_options(uuid) to authenticated;


commit;
