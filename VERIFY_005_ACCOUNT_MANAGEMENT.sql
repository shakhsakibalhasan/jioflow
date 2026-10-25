-- Read-only verification after applying migration 005.
select version from public.jf_schema_versions where version='005_account_management';
select to_regprocedure('public.jf_manage_account(uuid,text,jsonb)') is not null as management_rpc_exists,
 to_regprocedure('public.jf_session_status()') is not null as session_status_exists;
select p.proname,position('session_allowed' in p.prosrc)>0 as session_gate_present
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='jioflow_private' and p.proname in
 ('is_creator','owns_shop','in_shop','manages_shop','can_read_profile','reads_operations','reads_finance','has_permission','can_provision');
