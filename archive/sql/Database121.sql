begin;
-- Match the new sidebar checkbox keys in both backend account-save validators.
do $patch$
declare fn record;d text;before_keys text:='''users'',''assign'',''booking'',''products'',''import'',''export'',''profit'',''settings'',''approval'',''logout'',''integration'',''pull'',''price'',''discount'',''advance''';
begin
 for fn in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.prokind='f' and (p.proname like 'jf_save_profile%' or p.proname='has_permission') loop
 d:=pg_get_functiondef(fn.oid);
 if position(before_keys in d)>0 then d:=replace(d,before_keys,before_keys||',''orders'',''permanent'',''courier''');execute d;end if;
 end loop;
end $patch$;
-- Confirmed ORDERS and confirmed CUSTOMER workflow are different counters.
-- Shop totals include all permitted Agent orders and orders entered by management.
create or replace function public.jf_order_kpi121(target_shop uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare staff boolean;mid uuid;answer jsonb;
begin
 staff:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);mid:=jioflow_private.agent_member(target_shop);
 if not staff and mid is null then raise exception 'Workspace access required.' using errcode='42501';end if;
 select jsonb_build_object('confirmed_orders',count(*) filter(where status not in('draft','cancelled')),'orders',count(*),'revenue',coalesce(sum(total) filter(where status not in('draft','cancelled')),0)) into answer
 from public.jf_orders where shop_id=target_shop and archived_at is null and (staff or assigned_membership_id=mid or entered_by=auth.uid());
 return answer;
end $$;
revoke all on function public.jf_order_kpi121(uuid) from public,anon;
grant execute on function public.jf_order_kpi121(uuid) to authenticated;
commit;
