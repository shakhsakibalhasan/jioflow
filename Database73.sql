begin;
-- Preserve the Agent RLS path; staff authorization is evaluated once per request.
do $patch$
declare item record;p record;body text;definition text;args text;sig text;backup text;helper text;
begin
 for item in select * from (values
 ('jf_workspace_page','uuid,text,jsonb,integer','target_shop,entity,filters,page_number'),
 ('jf_workspace_page_fast','uuid,text,jsonb,integer','target_shop,entity,filters,page_number'),
 ('jf_agent_totals','uuid','target_shop')) v(name,types,callargs)
 loop
  backup:=item.name||'_rls73';helper:=item.name||'_staff73';sig:='public.'||item.name||'('||item.types||')';
  if to_regprocedure('public.'||backup||'('||item.types||')') is null then
   select pr.*,l.lanname into p from pg_proc pr join pg_language l on l.oid=pr.prolang where pr.oid=sig::regprocedure;
   if p.prosecdef then raise exception 'Expected RLS function: %',item.name;end if;
   definition:=pg_get_functiondef(p.oid);args:=pg_get_function_arguments(p.oid);
   execute replace(definition,'public.'||item.name||'(','public.'||backup||'(');
   body:=p.prosrc;
   if p.lanname='plpgsql' then
    body:=regexp_replace(body,'\mbegin\M',E'begin\n if not coalesce(jioflow_private.reads_staff_operations(target_shop),false) then raise exception ''Staff workspace access required.'' using errcode=''42501'';end if;','i');
   elsif p.lanname='sql' then
    body:='begin if not coalesce(jioflow_private.reads_staff_operations(target_shop),false) then raise exception ''Staff workspace access required.'' using errcode=''42501'';end if;return ('||regexp_replace(trim(body),';\s*$','')||');end';
   else raise exception 'Unexpected function language.';end if;
   execute format('create function jioflow_private.%I(%s) returns jsonb language plpgsql stable security definer set search_path='''' as %L',helper,args,body);
   execute format('create or replace function public.%I(%s) returns jsonb language plpgsql stable security invoker set search_path='''' as %L',item.name,args,
    'begin if coalesce(jioflow_private.reads_staff_operations(target_shop),false) then return jioflow_private.'||helper||'('||item.callargs||');end if;return public.'||backup||'('||item.callargs||');end');
  end if;
  execute 'revoke all on function public.'||backup||'('||item.types||') from public,anon';
  execute 'grant execute on function public.'||backup||'('||item.types||') to authenticated';
  execute 'revoke all on function jioflow_private.'||helper||'('||item.types||') from public,anon';
  execute 'grant execute on function jioflow_private.'||helper||'('||item.types||') to authenticated';
 end loop;
end $patch$;
insert into public.jf_schema_versions(version) values('051_scoped_staff_reads') on conflict do nothing;
commit;
