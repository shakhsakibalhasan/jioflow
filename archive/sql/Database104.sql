begin;
-- Require the matching-date and latest-status projection before changing the fast route.
do $$begin
 if position('latest103 as materialized(' in pg_get_functiondef('jioflow_private.jf_workspace_page_staff73(uuid,text,jsonb,integer)'::regprocedure))=0 then
 raise exception 'Apply Database102.sql and Database103.sql before Database104.sql.';
 end if;
end $$;
-- The old unfiltered All shortcut omitted dates, amounts and latest order status.
-- Reuse the indexed batch projection with _fast=true: retain deferred totals, return essential row values.
create or replace function jioflow_private.jf_workspace_page_fast_staff73(target_shop uuid,entity text,filters jsonb default '{}',page_number integer default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not coalesce(jioflow_private.reads_staff_operations(target_shop),false) then raise exception 'Staff workspace access required.' using errcode='42501';end if;
 return jioflow_private.jf_workspace_page_staff73(target_shop,entity,coalesce(filters,'{}')||jsonb_build_object('_fast',true),page_number);
end $$;
revoke all on function jioflow_private.jf_workspace_page_fast_staff73(uuid,text,jsonb,integer) from public,anon;
grant execute on function jioflow_private.jf_workspace_page_fast_staff73(uuid,text,jsonb,integer) to authenticated;
commit;
