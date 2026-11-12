begin;
-- Preserve unknown legacy history instead of labelling it Never Assigned.
alter table public.jf_customers add column if not exists assignment_known171 boolean not null default false;
alter table public.jf_customers add column if not exists ever_assigned171 boolean not null default false;
alter table public.jf_customers alter column assignment_known171 set default true;
update public.jf_customers c set assignment_known171=true,ever_assigned171=true where not ever_assigned171 and (assigned_membership_id is not null or nullif(trim(unassignment_tag),'') is not null or exists(select 1 from jioflow_private.jf_assignment_history168 h where h.shop_id=c.shop_id and h.customer_id=c.id and h.membership_id is not null));
create or replace function jioflow_private.jf_assignment_flags171() returns trigger language plpgsql security definer set search_path='' as $$begin
 if tg_op='INSERT' then new.assignment_known171:=true;new.ever_assigned171:=new.assigned_membership_id is not null;
 elsif new.assigned_membership_id is distinct from old.assigned_membership_id then new.assignment_known171:=true;new.ever_assigned171:=old.ever_assigned171 or old.assigned_membership_id is not null or new.assigned_membership_id is not null;else new.ever_assigned171:=old.ever_assigned171;new.assignment_known171:=old.assignment_known171;end if;return new;end$$;
revoke all on function jioflow_private.jf_assignment_flags171() from public,anon,authenticated;
drop trigger if exists jf_assignment_flags171 on public.jf_customers;
create trigger jf_assignment_flags171 before insert or update on public.jf_customers for each row execute function jioflow_private.jf_assignment_flags171();
-- Main bucket constrains the base cohort, so status/tag counts reflect that bucket.
do $patch$
declare r record;d text;extra text:=$extra$c.archived_at is null and (/*buckets171*/ coalesce(filters->>'_bucket171','all')='all' or filters->>'_bucket171'='unassigned' and c.assigned_membership_id is null or filters->>'_bucket171'='assigned' and c.assigned_membership_id is not null or filters->>'_bucket171'='permanent' and c.permanent or filters->>'_bucket171'='completed' and coalesce((select public.jf_followup_done139(fp.status,fp.call_outcome) from public.jf_followups fp where fp.shop_id=target_shop and fp.customer_id=c.id),false) and ((nullif(filters->>'report_start','') is null and nullif(filters->>'report_end','') is null) or c.id in(select customer_id from jioflow_private.jf_contact_customers168(target_shop,nullif(filters->>'report_start','')::timestamptz,nullif(filters->>'report_end','')::timestamptz)))) and (coalesce(filters->>'_never171','false')<>'true' or c.assignment_known171 and not c.ever_assigned171 and c.assigned_membership_id is null and nullif(trim(c.unassignment_tag),'') is null)$extra$;
begin
 for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname in('jf_agent_page78','jf_workspace_page_rls73','jf_workspace_page_staff73') loop
 d:=pg_get_functiondef(r.oid);if position('buckets171' in d)=0 then
 if position('c.archived_at is null' in d)=0 then raise exception 'Follow-up bucket patch target missing: %',r.oid::regprocedure;end if;
 d:=replace(d,'c.archived_at is null',extra);
 d:=replace(d,$old$st='all' or st='unassigned'$old$,$new$st='never_assigned171' and c.assignment_known171 and not c.ever_assigned171 and c.assigned_membership_id is null and nullif(trim(c.unassignment_tag),'') is null or st=('tag171:'||encode(convert_to(c.unassignment_tag,'UTF8'),'hex')) or st='all' or st='unassigned'$new$);
 d:=replace(d,'''all'',count(*) filter(where true)', '''all'',count(*) filter(where true),''history_unknown171'',count(*) filter(where not assignment_known171 and assigned_membership_id is null),''never_assigned171'',count(*) filter(where assignment_known171 and not ever_assigned171 and assigned_membership_id is null and nullif(trim(unassignment_tag),'''') is null),''tags171'',(select coalesce(jsonb_object_agg(t.tag,t.n),''{}''::jsonb) from(select unassignment_tag tag,count(*) n from base where nullif(trim(unassignment_tag),'''') is not null group by unassignment_tag)t)');
 execute d;end if;end loop;
end $patch$;
create or replace function public.jf_followup_page171(target_shop uuid,entity text,filters jsonb default '{}',page_number int default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare bucket text:=coalesce(filters->>'group171','unassigned');sub text:=coalesce(filters->>'sub171','never');f jsonb;result jsonb;global_counts jsonb;begin
 if entity<>'customers' then raise exception 'Follow-up tabs apply to customers only.';end if;
 if not coalesce(jioflow_private.session_allowed(),false) then raise exception 'Workspace access required.' using errcode='42501';end if;
 if bucket not in('all','assigned','unassigned','completed','permanent') or length(sub)>160 then raise exception 'Invalid Follow-up selection.';end if;
 f:=(coalesce(filters,'{}')-array['group171','sub171','_never171','tag'])||jsonb_build_object('_bucket171',bucket,'status','all');
 if bucket='unassigned' then
 if sub='never' then f:=f||jsonb_build_object('status','never_assigned171');elsif sub<>'all' then f:=f||jsonb_build_object('status','tag171:'||encode(convert_to(sub,'UTF8'),'hex'));end if;
 elsif sub<>'all' then f:=f||jsonb_build_object('status','workflow142:'||encode(convert_to(sub,'UTF8'),'hex'));end if;
 if coalesce(filters->>'_fast','false')='true' then return public.jf_workspace_page_fast(target_shop,entity,f,page_number);end if;
 result:=public.jf_workspace_page(target_shop,entity,f,page_number);
 result:=result||jsonb_build_object('sub_counts171',result->'counts');
 global_counts:=(public.jf_workspace_page(target_shop,entity,(f-array['_bucket171','_never171','tag'])||jsonb_build_object('status','all','_page_size',1),0))->'counts';
 return result||jsonb_build_object('primary_counts171',global_counts);
end$$;
revoke all on function public.jf_followup_page171(uuid,text,jsonb,int) from public,anon;
grant execute on function public.jf_followup_page171(uuid,text,jsonb,int) to authenticated;
commit;
