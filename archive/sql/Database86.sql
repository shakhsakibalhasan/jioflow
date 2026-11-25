begin;
create or replace function public.jf_page_size75(filters jsonb) returns integer language sql immutable security invoker set search_path='' as $$
 select case coalesce(filters->>'_page_size','') when '20' then 20 when '50' then 50 when '100' then 100 when '200' then 200 when '500' then 500 when '1000' then 1000 else 50 end;
$$;
revoke all on function public.jf_page_size75(jsonb) from public,anon;
grant execute on function public.jf_page_size75(jsonb) to authenticated;
commit;
