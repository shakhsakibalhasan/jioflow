-- Run after migration 002. These are read-only checks.
select version, applied_at from public.jf_schema_versions order by version;
select tablename, rowsecurity from pg_tables
where schemaname='public' and tablename like 'jf_%' order by tablename;
-- Expected: ZERO rows. No authenticated/anonymous browser mutation grants.
select grantee, table_name, privilege_type from information_schema.role_table_grants
where table_schema='public' and table_name like 'jf_%'
  and grantee in ('anon','authenticated','PUBLIC')
  and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE');
-- Expected: 20 tables total, including the three phase-1 identity tables.
select count(*) as jioflow_table_count from pg_tables
where schemaname='public' and tablename like 'jf_%';
