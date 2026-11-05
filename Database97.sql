begin;
-- Report reads currently repeat RLS checks for every scanned customer/order.
-- Retain the original explicit shop management guard before executing the report.
do $patch$
declare d text;
begin
 d:=pg_get_functiondef('public.jf_agent_report(uuid,uuid,timestamp with time zone,timestamp with time zone)'::regprocedure);
 if position('jioflow_private.manages_shop(target_shop)' in d)=0 or position('Agent reporting access denied.' in d)=0 then raise exception 'Report access guard changed; review before applying Update 97.';end if;
 d:=replace(d,'SECURITY INVOKER','SECURITY DEFINER');
 -- pg_get_functiondef omits SECURITY INVOKER when it is the default.
 if position('SECURITY DEFINER' in d)=0 then d:=replace(d,'SET search_path',E'SECURITY DEFINER\n SET search_path');end if;
 execute d;
end $patch$;
revoke all on function public.jf_agent_report(uuid,uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.jf_agent_report(uuid,uuid,timestamptz,timestamptz) to authenticated;
create index if not exists jf_report_customer97 on public.jf_customers(shop_id,assigned_membership_id) where archived_at is null;
create index if not exists jf_report_orders97 on public.jf_orders(shop_id,assigned_membership_id,created_at) where archived_at is null;
create index if not exists jf_report_followup_activity97 on public.jf_followup_events(shop_id,actor_id,created_at desc);
create index if not exists jf_report_order_activity97 on public.jf_order_events(shop_id,actor_id,created_at desc);
commit;
