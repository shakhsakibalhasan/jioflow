-- Read-only checks after migration 004.
select version,applied_at from public.jf_schema_versions order by version;
select
 not has_function_privilege('anon','public.jf_save_product(uuid,uuid,jsonb)','EXECUTE') as anonymous_product_write_blocked,
 not has_function_privilege('anon','public.jf_save_customer(uuid,uuid,jsonb)','EXECUTE') as anonymous_customer_write_blocked,
 not has_function_privilege('anon','public.jf_record_followup(uuid,uuid,text,text,timestamptz,text)','EXECUTE') as anonymous_followup_write_blocked,
 not exists(select 1 from pg_tables where schemaname='public' and tablename like 'jf_%' and not rowsecurity) as all_rls_enabled;
