begin;
-- Match the existing Agent RLS scope once instead of repeating session checks per row.
do $patch$ declare p record;body text;args text;begin
 select pr.* into p from pg_proc pr where pr.oid='public.jf_workspace_page_rls73(uuid,text,jsonb,integer)'::regprocedure;
 args:=pg_get_function_arguments(p.oid);body:=replace(p.prosrc,'declare result jsonb;','declare actor_member uuid;result jsonb;');
 body:=replace(body,'public.jf_customers c','(select * from public.jf_customers where shop_id=target_shop and assigned_membership_id=actor_member) c');
 body:=replace(body,'public.jf_orders','(select * from public.jf_orders where shop_id=target_shop and (assigned_membership_id=actor_member or entered_by=auth.uid()))');
 body:=regexp_replace(body,'\mbegin\M',E'begin\n actor_member:=jioflow_private.agent_member(target_shop);if actor_member is null then raise exception ''Approved Agent access required.'' using errcode=''42501'';end if;filters:=coalesce(filters,''{}'')||''{"_fast":true}'';if entity=''customers'' then agent_id:=coalesce(agent_id,actor_member);end if;','i');
 execute format('create or replace function jioflow_private.jf_agent_page78(%s) returns jsonb language plpgsql stable security definer set search_path='''' as %L',args,body);
end $patch$;
revoke all on function jioflow_private.jf_agent_page78(uuid,text,jsonb,integer) from public,anon;
grant execute on function jioflow_private.jf_agent_page78(uuid,text,jsonb,integer) to authenticated;
create or replace function public.jf_workspace_page_fast(target_shop uuid,entity text,filters jsonb default '{}',page_number integer default 0) returns jsonb language plpgsql stable security invoker set search_path='' as $$
begin
 if coalesce(jioflow_private.reads_staff_operations(target_shop),false) then return jioflow_private.jf_workspace_page_fast_staff73(target_shop,entity,filters,page_number);end if;
 if jioflow_private.agent_member(target_shop) is not null then return jioflow_private.jf_agent_page78(target_shop,entity,filters,page_number);end if;
 return public.jf_workspace_page_fast_rls73(target_shop,entity,filters,page_number);
end $$;
insert into public.jf_schema_versions(version) values('054_agent_followup_scope') on conflict do nothing;
commit;
