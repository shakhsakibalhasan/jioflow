begin;
create index if not exists jf_assignment_customer176 on jioflow_private.jf_assignment_history168(shop_id,customer_id,created_at desc) where membership_id is not null;
create or replace function jioflow_private.jf_unworked176(target_shop uuid,target_customer uuid)
returns boolean language sql stable security definer set search_path='' as $$
select not exists(select 1 from public.jf_followups f where f.shop_id=target_shop and f.customer_id=target_customer and public.jf_followup_done139(f.status,f.call_outcome) and f.last_contact_at>=coalesce((select max(h.created_at) from jioflow_private.jf_assignment_history168 h where h.shop_id=target_shop and h.customer_id=target_customer and h.membership_id is not null),'-infinity'::timestamptz))
$$;
revoke all on function jioflow_private.jf_unworked176(uuid,uuid) from public,anon,authenticated;
do $patch$
declare r record;d text;begin
for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname in('jf_agent_page78','jf_workspace_page_rls73','jf_workspace_page_staff73') loop
 d:=pg_get_functiondef(r.oid);
 if position('/*unworked176*/' in d)=0 then
 d:=replace(d,'c.archived_at is null', $x$c.archived_at is null and (/*unworked176*/coalesce(filters->>'_processing176','false')<>'true' or c.assigned_membership_id is not null and jioflow_private.jf_unworked176(target_shop,c.id))$x$);
 d:=replace(d,'''all'',count(*) filter(where true)', '''all'',count(*) filter(where true),''processing176'',count(*) filter(where assigned_membership_id is not null and jioflow_private.jf_unworked176(target_shop,id))');
 execute d;
 end if;
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
 if sub='never' then f:=f||jsonb_build_object('status','never_assigned171');elsif bucket='assigned' and sub='processing176' then f:=f||jsonb_build_object('_processing176',true);
 elsif sub<>'all' then f:=f||jsonb_build_object('status','tag171:'||encode(convert_to(sub,'UTF8'),'hex'));end if;
 elsif bucket='assigned' and sub='processing176' then f:=f||jsonb_build_object('_processing176',true);
 elsif sub<>'all' then f:=f||jsonb_build_object('status','workflow142:'||encode(convert_to(sub,'UTF8'),'hex'));end if;
 if coalesce(filters->>'_fast','false')='true' then return public.jf_workspace_page_fast(target_shop,entity,f,page_number);end if;
 result:=public.jf_workspace_page(target_shop,entity,f,page_number);
 result:=result||jsonb_build_object('sub_counts171',result->'counts');
 global_counts:=(public.jf_workspace_page(target_shop,entity,(f-array['_bucket171','_never171','tag','_processing176'])||jsonb_build_object('status','all','_page_size',1),0))->'counts';
 return result||jsonb_build_object('primary_counts171',global_counts);
end$$;
revoke all on function public.jf_followup_page171(uuid,text,jsonb,int) from public,anon;
grant execute on function public.jf_followup_page171(uuid,text,jsonb,int) to authenticated;
commit;
