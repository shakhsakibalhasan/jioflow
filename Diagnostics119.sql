-- Read-only checks. Run in Supabase SQL Editor and share the result tables (no customer records).
select current_setting('statement_timeout') as editor_statement_timeout;
select rolname,rolconfig from pg_roles where rolname in ('authenticated','anon','authenticator');
select n.nspname,p.proname,md5(p.prosrc) as definition_hash,
 position('jf_latest_history117' in p.prosrc)>0 as uses_latest_summary,
 position('latest116' in p.prosrc)>0 as shares_latest_calculation,
 position('jf_history_summary117' in p.prosrc)>0 as uses_parsed_summary
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where p.proname in ('jf_latest_orders112','jf_workspace_page_staff73','jf_workspace_page_fast_staff73','jf_followup_filter_options');
select schemaname,relname,n_live_tup,n_dead_tup,last_analyze,last_autoanalyze from pg_stat_user_tables where relname in ('jf_customers','jf_followups','jf_orders','jf_order_history','jf_history_summary117','jf_latest_history117');
select schemaname,tablename,indexname,indexdef from pg_indexes where tablename in ('jf_history_summary117','jf_latest_history117','jf_customers','jf_followups');
select wait_event_type,wait_event,state,count(*) as connections from pg_stat_activity where datname=current_database() group by 1,2,3 order by 4 desc;
