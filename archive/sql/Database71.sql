begin;
create index if not exists jf_history_stage_pending on public.jf_history_stage(job_id,row_number) where not done;
create index if not exists jf_followup_lookup71 on public.jf_followups(shop_id,customer_id);
create index if not exists jf_history_latest71 on public.jf_order_history(shop_id,customer_id,updated_at desc,id);
create index if not exists jf_notes_latest71 on public.jf_notes(shop_id,customer_id,created_at desc,id desc);
create index if not exists jf_customer_assigned71 on public.jf_customers(shop_id,assigned_membership_id,updated_at desc,id) where archived_at is null;
-- Stage each chunk in one statement rather than one INSERT per row.
do $patch$ declare body text; begin
body:=pg_get_functiondef('public.jf_history_import(uuid,text,jsonb)'::regprocedure);
body:=replace(body,$old$n:=(details->>'offset')::integer;for x in select * from jsonb_array_elements(details->'rows') loop
   insert into public.jf_history_stage(job_id,row_number,payload) values(jid,n,x) on conflict do nothing;n:=n+1;
  end loop;$old$,$new$n:=(details->>'offset')::integer;
  insert into public.jf_history_stage(job_id,row_number,payload)
  select jid,n+ordinality::integer-1,value from jsonb_array_elements(details->'rows') with ordinality
  on conflict do nothing;$new$);
body:=replace(body,$old$update public.jf_history_jobs set staged=(select count(*) from public.jf_history_stage where job_id=jid) where id=jid;$old$,$new$get diagnostics n = row_count;
  update public.jf_history_jobs set staged=staged+n where id=jid;$new$);
execute body;
end $patch$;
create or replace function public.jf_workspace_page_fast(target_shop uuid,entity text,filters jsonb default '{}',page_number integer default 0) returns jsonb
language plpgsql stable security invoker set search_path='' as $$
declare result jsonb;search text:=trim(coalesce(filters->>'search',''));agent_id uuid:=nullif(filters->>'agent_id','')::uuid;
begin
 if page_number is null or page_number<0 or length(search)>200 then raise exception 'Invalid page filter.';end if;
 if entity='customers' and coalesce(filters->>'status','all')='all' and not exists(
 select 1 from jsonb_each_text(coalesce(filters,'{}')) x where x.key not in('status','search','agent_id','source','tag','_fast') and coalesce(x.value,'')<>'') then
 -- Count customer IDs without joining every customer's follow-up first.
 -- RLS still applies to both matching customers and the final page join.
 with matching as not materialized(select c.* from public.jf_customers c
 where c.shop_id=target_shop and c.archived_at is null
 and (agent_id is null or c.assigned_membership_id=agent_id)
 and (coalesce(filters->>'source','')='' or lower(c.source)=lower(filters->>'source'))
 and (coalesce(filters->>'tag','')='' or c.unassignment_tag=filters->>'tag')
 and (search='' or c.full_name ilike '%'||search||'%' or c.phone ilike '%'||search||'%' or c.address ilike '%'||search||'%')),
 page as materialized(select * from matching order by updated_at desc,id limit 50 offset page_number::bigint*50)
 select jsonb_build_object('counts',null,'total',(select count(*) from matching),'rows',coalesce((select jsonb_agg(to_jsonb(t) order by t.updated_at desc,t.id) from (
 select p.*,f.status followup_status,f.call_outcome,f.callback_at,false has_confirmed from page p left join public.jf_followups f on f.shop_id=p.shop_id and f.customer_id=p.id)t),'[]'::jsonb)) into result;
 return result;
 end if;
 return public.jf_workspace_page(target_shop,entity,coalesce(filters,'{}')||jsonb_build_object('_fast',true),page_number);
end $$;

insert into public.jf_schema_versions(version) values('049_import_queue_speed') on conflict do nothing;
commit;
