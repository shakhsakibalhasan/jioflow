begin;
do $patch$
declare r record;d text;head text;body text;tail text;a integer;b integer;begin
for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname in('jf_agent_page78','jf_workspace_page_rls73','jf_workspace_page_staff73') loop
 d:=pg_get_functiondef(r.oid);
 if position('scope181 as materialized' in d)>0 then continue;end if;
 a:=position($m$ if entity='customers' then$m$ in d);b:=position($m$elsif entity='orders' then$m$ in d);
 if a=0 or b<=a then raise exception 'Customer optimization target missing: %',r.oid::regprocedure;end if;
 head:=left(d,a-1);body:=substring(d from a for b-a);tail:=substring(d from b);
 if position($old$ and (/*unworked176*/coalesce(filters->>'_processing176','false')<>'true' or c.assigned_membership_id is not null and jioflow_private.jf_unworked176(target_shop,c.id)) and (/*buckets171*/ coalesce(filters->>'_bucket171','all')='all' or filters->>'_bucket171'='unassigned' and c.assigned_membership_id is null or filters->>'_bucket171'='assigned' and c.assigned_membership_id is not null or filters->>'_bucket171'='permanent' and c.permanent or filters->>'_bucket171'='completed' and coalesce((select public.jf_followup_done139(fp.status,fp.call_outcome) from public.jf_followups fp where fp.shop_id=target_shop and fp.customer_id=c.id),false) and ((nullif(filters->>'report_start','') is null and nullif(filters->>'report_end','') is null) or c.id in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,nullif(filters->>'report_start','')::timestamptz,nullif(filters->>'report_end','')::timestamptz)))) and (coalesce(filters->>'_never171','false')<>'true' or c.assignment_known171 and not c.ever_assigned171 and c.assigned_membership_id is null and nullif(trim(c.unassignment_tag),'') is null)$old$ in body)=0 then raise exception 'Follow-up scope target missing: %',r.oid::regprocedure;end if;
 body:=replace(body,$old$ and (/*unworked176*/coalesce(filters->>'_processing176','false')<>'true' or c.assigned_membership_id is not null and jioflow_private.jf_unworked176(target_shop,c.id)) and (/*buckets171*/ coalesce(filters->>'_bucket171','all')='all' or filters->>'_bucket171'='unassigned' and c.assigned_membership_id is null or filters->>'_bucket171'='assigned' and c.assigned_membership_id is not null or filters->>'_bucket171'='permanent' and c.permanent or filters->>'_bucket171'='completed' and coalesce((select public.jf_followup_done139(fp.status,fp.call_outcome) from public.jf_followups fp where fp.shop_id=target_shop and fp.customer_id=c.id),false) and ((nullif(filters->>'report_start','') is null and nullif(filters->>'report_end','') is null) or c.id in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,nullif(filters->>'report_start','')::timestamptz,nullif(filters->>'report_end','')::timestamptz)))) and (coalesce(filters->>'_never171','false')<>'true' or c.assignment_known171 and not c.ever_assigned171 and c.assigned_membership_id is null and nullif(trim(c.unassignment_tag),'') is null)$old$,$fast$ and (coalesce(filters->>'_fast','false')<>'true' or (true and (/*unworked176*/coalesce(filters->>'_processing176','false')<>'true' or c.assigned_membership_id is not null and jioflow_private.jf_unworked176(target_shop,c.id)) and (/*buckets171*/ coalesce(filters->>'_bucket171','all')='all' or filters->>'_bucket171'='unassigned' and c.assigned_membership_id is null or filters->>'_bucket171'='assigned' and c.assigned_membership_id is not null or filters->>'_bucket171'='permanent' and c.permanent or filters->>'_bucket171'='completed' and coalesce((select public.jf_followup_done139(fp.status,fp.call_outcome) from public.jf_followups fp where fp.shop_id=target_shop and fp.customer_id=c.id),false) and ((nullif(filters->>'report_start','') is null and nullif(filters->>'report_end','') is null) or c.id in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,nullif(filters->>'report_start','')::timestamptz,nullif(filters->>'report_end','')::timestamptz)))) and (coalesce(filters->>'_never171','false')<>'true' or c.assignment_known171 and not c.ever_assigned171 and c.assigned_membership_id is null and nullif(trim(c.unassignment_tag),'') is null)))$fast$);
 body:=replace(body,'base as materialized(select c.*,f.status','scope181 as materialized(select c.*,f.status');
 body:=replace(body,')),c as(select * from base c where',$new$)),base as materialized(select * from scope181 c where true and (/*unworked176*/coalesce(filters->>'_processing176','false')<>'true' or c.assigned_membership_id is not null and jioflow_private.jf_unworked176(target_shop,c.id)) and (/*buckets171*/ coalesce(filters->>'_bucket171','all')='all' or filters->>'_bucket171'='unassigned' and c.assigned_membership_id is null or filters->>'_bucket171'='assigned' and c.assigned_membership_id is not null or filters->>'_bucket171'='permanent' and c.permanent or filters->>'_bucket171'='completed' and public.jf_followup_done139(c.followup_status,c.call_outcome) and ((nullif(filters->>'report_start','') is null and nullif(filters->>'report_end','') is null) or c.id in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,nullif(filters->>'report_start','')::timestamptz,nullif(filters->>'report_end','')::timestamptz)))) and (coalesce(filters->>'_never171','false')<>'true' or c.assignment_known171 and not c.ever_assigned171 and c.assigned_membership_id is null and nullif(trim(c.unassignment_tag),'') is null)),c as(select * from base c where$new$);
 body:=replace(body,$m$'total',(select count(*) from c)$m$,$new$'primary_counts181',case when filters?'_bucket171' and coalesce(filters->>'_fast','false')<>'true' then (select jsonb_build_object('all',count(*),'unassigned',count(*) filter(where assigned_membership_id is null),'assigned',count(*) filter(where assigned_membership_id is not null),'permanent',count(*) filter(where permanent),'completed',count(*) filter(where (public.jf_followup_done139(followup_status,call_outcome) and ((nullif(filters->>'report_start','') is null and nullif(filters->>'report_end','') is null) or id in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,nullif(filters->>'report_start','')::timestamptz,nullif(filters->>'report_end','')::timestamptz)))))) from scope181) else null end, 'total',(select count(*) from c)$new$);
 if position('scope181 as materialized' in body)=0 or position('primary_counts181' in body)=0 then raise exception 'Incomplete customer optimization';end if;
 execute head||body||tail;
end loop;
end $patch$;
create or replace function public.jf_followup_page171(target_shop uuid,entity text,filters jsonb default '{}',page_number int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare bucket text:=coalesce(filters->>'group171','unassigned');sub text:=coalesce(filters->>'sub171','never');f jsonb;result jsonb;global_counts jsonb;begin
 if entity<>'customers' then raise exception 'Follow-up tabs apply to customers only.';end if;
 if not coalesce(jioflow_private.session_allowed(),false) then raise exception 'Workspace access required.' using errcode='42501';end if;
 if bucket not in('all','assigned','unassigned','completed','permanent') or length(sub)>160 then raise exception 'Invalid Follow-up selection.';end if;
 f:=(coalesce(filters,'{}')-array['group171','sub171','_never171','tag','_processing176'])||jsonb_build_object('_bucket171',bucket,'status','all');
 if bucket='unassigned' then
 if sub='never' then f:=f||jsonb_build_object('status','never_assigned171');
 elsif sub<>'all' then f:=f||jsonb_build_object('status','tag171:'||encode(convert_to(sub,'UTF8'),'hex'));end if;
 elsif bucket='assigned' and sub='processing176' then f:=f||jsonb_build_object('_processing176',true);
 elsif sub<>'all' then f:=f||jsonb_build_object('status','workflow142:'||encode(convert_to(sub,'UTF8'),'hex'));end if;
 if coalesce(filters->>'_fast','false')='true' then return public.jf_workspace_page_fast(target_shop,entity,f,page_number);end if;
 result:=public.jf_workspace_page(target_shop,entity,f,page_number);
 result:=result||jsonb_build_object('sub_counts171',result->'counts');
 global_counts:=result->'primary_counts181';result:=result-'primary_counts181';
 return result||jsonb_build_object('primary_counts171',global_counts);
end$$;
revoke all on function public.jf_followup_page171(uuid,text,jsonb,int) from public,anon;
grant execute on function public.jf_followup_page171(uuid,text,jsonb,int) to authenticated;


CREATE OR REPLACE FUNCTION public.jf_panel_heartbeat(device_id text, target_shop uuid DEFAULT NULL::uuid, include_inbox boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare allowed boolean;gate jsonb;workspace jsonb;feed jsonb;resets jsonb;logins jsonb;creator boolean;
begin
 allowed:=public.jf_session_status();
 if not coalesce(allowed,false) then return jsonb_build_object('allowed',false);end if;
 workspace:=public.jf_workspace_status();
 gate:=public.jf_agent_session(device_id); perform public.jf_presence135();
 if include_inbox then
  feed:=public.jf_notifications_feed(target_shop);
 end if; -- Ordinary inbox is optional; approval queues remain on every heartbeat.
  begin resets:=public.jf_password_requests_feed();exception when insufficient_privilege then resets:='[]'::jsonb;end;
  select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into logins from(select * from public.jf_agent_sessions where status='pending' order by requested_at desc limit 100)t;
 return jsonb_build_object('change_stamp152',case when coalesce((gate->>'is_agent')::boolean,false) and gate->>'status'<>'approved' then null else public.jf_change_stamp152(target_shop) end,'allowed',true,'gate',gate,'workspace',workspace,'feed',feed,'resets',resets,'logins',logins);
end$function$
;


commit;
