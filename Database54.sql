-- Update 52: authorize once, then aggregate only the caller's permitted records.
-- Does not change table RLS policies or expose a general-purpose bypass RPC.
begin;
create or replace function public.jf_workspace_summary(target_shop uuid,report_start timestamptz default null,report_end timestamptz default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare staff_access boolean; agent_id uuid; caller_id uuid:=auth.uid(); result jsonb;
begin
 if caller_id is null or not jioflow_private.session_allowed() or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null) then
  raise exception 'Workspace access denied.' using errcode='42501';
 end if;
 staff_access:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);
 agent_id:=jioflow_private.agent_member(target_shop);
 if not staff_access and agent_id is null then raise exception 'Workspace access denied.' using errcode='42501';end if;
 with c as(select c.id,c.assigned_membership_id,c.permanent,f.status followup_status,f.call_outcome,f.callback_at from public.jf_customers c left join public.jf_followups f on f.shop_id=c.shop_id and f.customer_id=c.id where c.shop_id=target_shop and c.archived_at is null and (staff_access or c.assigned_membership_id=agent_id)),o as(select customer_id,status,total,source,created_at from public.jf_orders where shop_id=target_shop and archived_at is null and (staff_access or assigned_membership_id=agent_id or entered_by=caller_id) and (report_start is null or created_at>=report_start) and (report_end is null or created_at<report_end))
, buyers as (select distinct customer_id from o where status not in ('draft','cancelled'))
 select jsonb_build_object('customers',(select count(*) from c),'unassigned',(select count(*) from c where assigned_membership_id is null),'assigned',(select count(*) from c where assigned_membership_id is not null),'completed',(select count(*) from c where followup_status='completed'),'pending',(select count(*) from c where coalesce(followup_status,'pending') in ('pending','callback')),'cancelled_customers',(select count(*) from c where followup_status='cancelled'),'permanent',(select count(*) from c where permanent),'connected',(select count(*) from c where call_outcome in ('connected','positive','negative','intermediate')),'not_connected',(select count(*) from c where call_outcome in ('not_connected','no_answer','busy')),'not_attempted',(select count(*) from c where call_outcome is null or call_outcome='not_attempted'),'positive',(select count(*) from c where call_outcome='positive'),'negative',(select count(*) from c where call_outcome='negative'),'intermediate',(select count(*) from c where call_outcome='intermediate'),'callbacks',(select count(*) from c where followup_status='callback' and callback_at<=now()),'orders',(select count(*) from o),'confirmed',(select count(*) from o where status not in ('draft','cancelled')),'draft',(select count(*) from o where status='draft'),'ready_to_book',(select count(*) from o where status in ('confirmed','ready_to_book')),'booked',(select count(*) from o where status='booked'),'in_transit',(select count(*) from o where status='in_transit'),'delivered',(select count(*) from o where status='delivered'),'returned',(select count(*) from o where status='returned'),'partial_delivery',(select count(*) from o where status='partial_delivery'),'cancelled',(select count(*) from o where status='cancelled'),'revenue',(select coalesce(sum(total),0) from o where status not in ('draft','cancelled')),'source_breakdown',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from(select case when lower(source) in('website','facebook','whatsapp') then lower(source) else 'other' end source,count(*) count from o where status not in('draft','cancelled') group by 1)t),'timeline',(select coalesce(jsonb_agg(to_jsonb(t) order by at,source),'[]') from(select date_trunc(case when report_end-report_start<=interval '1 day' then 'hour' else 'day' end,created_at at time zone 'Asia/Dhaka') at,case when lower(source) in('website','facebook','whatsapp') then lower(source) else 'other' end source,count(*) count from o where status not in('draft','cancelled') and created_at>=coalesce(report_end,now())-interval '30 days' group by 1,2)t),'purchase_rate',(select case when count(*) filter(where followup_status='completed')=0 then 0 else 100.0*count(*) filter(where followup_status='completed' and buyers.customer_id is not null)/count(*) filter(where followup_status='completed') end from c left join buyers on buyers.customer_id=c.id)) into result;
 return result;
end $$;
revoke all on function public.jf_workspace_summary(uuid,timestamptz,timestamptz) from public,anon;
grant execute on function public.jf_workspace_summary(uuid,timestamptz,timestamptz) to authenticated;
create index if not exists jf_summary_customers_active on public.jf_customers(shop_id,assigned_membership_id,id) where archived_at is null;
create index if not exists jf_summary_orders_active on public.jf_orders(shop_id,created_at,customer_id) where archived_at is null;
create index if not exists jf_summary_followup_customer on public.jf_followups(shop_id,customer_id);
insert into public.jf_schema_versions(version) values('033_workspace_summary_performance') on conflict do nothing;
commit;

begin;
create or replace function public.jf_assign_customers(target_shop uuid,details jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare ids uuid[]; agents uuid[]; requested uuid[]; gid uuid; cid uuid; idx integer:=0;mid uuid;
begin
 if not jioflow_private.session_allowed() or not jioflow_private.reads_staff_operations(target_shop) or not jioflow_private.has_permission(target_shop,'assign') or jioflow_private.agent_member(target_shop) is not null or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null) then raise exception 'Distribution permission required.' using errcode='42501';end if;
 ids:=array(select distinct x::uuid from jsonb_array_elements_text(coalesce(details->'ids','[]'))x);
 if cardinality(ids)=0 then raise exception 'Select customers first.';end if;
 gid:=nullif(details->>'group_id','')::uuid;
 requested:=array(select distinct x::uuid from jsonb_array_elements_text(coalesce(details->'membership_ids','[]'))x);
 if gid is not null then
  if not exists(select 1 from public.jf_groups where id=gid and shop_id=target_shop and active) then raise exception 'Choose an active group in this shop.';end if;
  requested:=array(select membership_id from public.jf_group_members where shop_id=target_shop and group_id=gid);
 end if;
 agents:=array(select distinct m.id from public.jf_memberships m join public.jf_profiles p on p.id=m.user_id where m.id=any(requested) and m.shop_id=target_shop and m.role='agent' and m.status='active' and p.active and p.deleted_at is null order by m.id);
 if cardinality(agents)=0 or (gid is null and cardinality(agents)<>cardinality(requested)) then raise exception 'Choose active Agents in this shop.';end if;
 perform 1 from public.jf_customers where shop_id=target_shop and id=any(ids) order by id for update;
 if (select count(*) from public.jf_customers where shop_id=target_shop and archived_at is null and id=any(ids))<>cardinality(ids) then raise exception 'A selected customer is unavailable in this shop.';end if;
 for cid in select id from public.jf_customers where shop_id=target_shop and id=any(ids) order by id loop
  mid:=agents[1+idx%cardinality(agents)];
  update public.jf_customers set assigned_membership_id=mid,permanent=case when coalesce((details->>'permanent')::boolean,false) then true else permanent end,updated_at=now() where shop_id=target_shop and id=cid;
  idx:=idx+1;
 end loop;
 return jsonb_build_object('assigned',idx,'agents',cardinality(agents));
end $$;
revoke all on function public.jf_assign_customers(uuid,jsonb) from public,anon;
grant execute on function public.jf_assign_customers(uuid,jsonb) to authenticated;
-- Support the per-customer enrichment in the follow-up page without scanning whole tables.
create index if not exists jf_followup_history_latest on public.jf_order_history(shop_id,customer_id,updated_at desc,id);
create index if not exists jf_followup_notes_latest on public.jf_notes(shop_id,customer_id,created_at desc,id desc);
create index if not exists jf_followup_orders_customer on public.jf_orders(shop_id,customer_id,created_at desc,id) where archived_at is null;
insert into public.jf_schema_versions(version) values('034_assignment_picker') on conflict do nothing;
commit;
begin;
create or replace function public.jf_followup_status(target_shop uuid,customer_id uuid,status_label text,callback_time timestamptz default null,note_text text default '') returns uuid
language plpgsql security definer set search_path='' as $$
declare fid uuid; next_status text:='pending';outcome text:='intermediate';
begin
 if not jioflow_private.session_allowed() or not jioflow_private.has_permission(target_shop,'assign') or not jioflow_private.can_read_customer(target_shop,customer_id) or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null) then raise exception 'Follow-up access denied.' using errcode='42501';end if;
 if status_label is null or status_label not in ('Processing','Confirm','Refuse','No Response','Don’t Call Again','Order Recently','Busy','Schedule','Problem Solve','Interested','Not Interested','For Relative','Irregular','FL - 7 Days Later','FL - 15 Days Later','FL - 1 Month Later','FL - 2 Months Later','FL - 3 Months Later') then raise exception 'Choose a valid follow-up status.';end if;
 perform 1 from public.jf_customers c where c.shop_id=target_shop and c.id=customer_id and c.archived_at is null for update;
 if not found then raise exception 'Customer not found.';end if;
 if status_label='Confirm' then next_status:='completed';outcome:='positive';
 elsif status_label in ('Refuse','Don’t Call Again','Not Interested') then next_status:='cancelled';outcome:='negative';
 elsif status_label='No Response' then outcome:='no_answer';
 elsif status_label='Busy' then outcome:='busy';
 elsif status_label in ('Interested','Problem Solve') then outcome:='positive';
 elsif status_label='Schedule' or status_label like 'FL - %' then next_status:='callback';outcome:='connected';end if;
 if next_status='callback' and callback_time is null then raise exception 'Select a callback date and time.';end if;
 fid:=public.jf_record_followup(target_shop,customer_id,next_status,outcome,callback_time,note_text);
 update public.jf_customers c set workflow_label=status_label,updated_at=now() where c.shop_id=target_shop and c.id=customer_id;
 return fid;
end $$;
revoke all on function public.jf_followup_status(uuid,uuid,text,timestamptz,text) from public,anon;
grant execute on function public.jf_followup_status(uuid,uuid,text,timestamptz,text) to authenticated;
insert into public.jf_schema_versions(version) values('035_followup_workspace') on conflict do nothing;
commit;
