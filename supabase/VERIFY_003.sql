-- Read-only verification after migration 003.
select version,applied_at from public.jf_schema_versions order by version;
select
 not exists(select 1 from pg_tables where schemaname='public' and tablename like 'jf_%' and not rowsecurity) as all_rls_enabled,
 not exists(select 1 from information_schema.role_table_grants where table_schema='public' and table_name like 'jf_%' and grantee in ('anon','authenticated','PUBLIC') and privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE')) as direct_browser_table_writes_blocked,
 not has_function_privilege('anon','public.jf_create_shop(text,text,text,text,text)','EXECUTE') as anonymous_shop_creation_blocked,
 not has_function_privilege('anon','public.jf_prepare_invitation(uuid,text,text,text,text)','EXECUTE') as anonymous_invitation_blocked,
 not has_function_privilege('anon','public.jf_finish_invitation(uuid,uuid)','EXECUTE') as anonymous_role_assignment_blocked;
