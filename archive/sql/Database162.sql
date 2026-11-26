begin;
-- Preserve installed guards and order validation in private, non-callable bases.
do $$declare d text;begin
 if to_regprocedure('jioflow_private.jf_save_order_base162(uuid,uuid,jsonb)') is null then
 select pg_get_functiondef('public.jf_save_order(uuid,uuid,jsonb)'::regprocedure) into d;
 execute replace(d,'FUNCTION public.jf_save_order(', 'FUNCTION jioflow_private.jf_save_order_base162(');end if;
 if to_regprocedure('jioflow_private.jf_followup_status_base162(uuid,uuid,text,timestamptz,text)') is null then
 select pg_get_functiondef('public.jf_followup_status(uuid,uuid,text,timestamptz,text)'::regprocedure) into d;
 execute replace(d,'FUNCTION public.jf_followup_status(', 'FUNCTION jioflow_private.jf_followup_status_base162(');end if;
end $$;
revoke all on function jioflow_private.jf_save_order_base162(uuid,uuid,jsonb) from public,anon,authenticated;
revoke all on function jioflow_private.jf_followup_status_base162(uuid,uuid,text,timestamptz,text) from public,anon,authenticated;
create table if not exists jioflow_private.confirm_context162(tx bigint,shop_id uuid,customer_id uuid,primary key(tx,shop_id,customer_id));
create table if not exists jioflow_private.confirm_orders162(order_id uuid primary key,created_at timestamptz not null default now());
revoke all on jioflow_private.confirm_context162,jioflow_private.confirm_orders162 from public,anon,authenticated;
create or replace function public.jf_followup_status(target_shop uuid,customer_id uuid,status_label text,callback_time timestamptz default null,note_text text default '') returns uuid language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from jsonb_array_elements(case when (select c.permanent from public.jf_customers c where c.shop_id=target_shop and c.id=customer_id) then jioflow_private.permanent_status_definitions(target_shop) else jioflow_private.status_definitions(target_shop) end) x where x->>'name'=status_label and x->>'kind'='confirm' and coalesce((x->>'active')::boolean,false)) and not exists(select 1 from jioflow_private.confirm_context162 t where t.tx=txid_current() and t.shop_id=target_shop and t.customer_id=jf_followup_status.customer_id) then
 raise exception 'Save an order to confirm this customer. Confirm cannot be saved with Update status.';end if;
 return jioflow_private.jf_followup_status_base162(target_shop,customer_id,status_label,callback_time,note_text);
end $$;
create or replace function public.jf_save_order(target_shop uuid,request_id uuid,details jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare oid uuid;cid uuid;label text;cs text;response text;begin
 if not coalesce(jioflow_private.session_allowed(),false) then raise exception 'Session access denied.' using errcode='42501';end if;
 cs:=details->>'call_status162';response:=nullif(details->>'customer_status162','');
 if cs is null or cs not in('connected','not_connected') or cs='connected' and (response is null or response not in('positive','negative','intermediate','irregular')) then raise exception 'Select Call Status and, when connected, Customer Status before saving the order.';end if;
 oid:=jioflow_private.jf_save_order_base162(target_shop,request_id,details);
 -- Same request replays neither the status nor the note.
 if exists(select 1 from jioflow_private.confirm_orders162 t where t.order_id=oid) then return oid;end if;
 select o.customer_id into cid from public.jf_orders o where o.id=oid and o.shop_id=target_shop and o.archived_at is null and o.status<>'draft';
 if cid is null then return oid;end if;
 select x->>'name' into label from jsonb_array_elements(case when (select c.permanent from public.jf_customers c where c.id=cid and c.shop_id=target_shop) then jioflow_private.permanent_status_definitions(target_shop) else jioflow_private.status_definitions(target_shop) end) x where x->>'kind'='confirm' and coalesce((x->>'active')::boolean,false) order by x->>'id' limit 1;
 if label is null then raise exception 'Configure an active Confirm status before saving this order.';end if;
 insert into jioflow_private.confirm_context162 values(txid_current(),target_shop,cid) on conflict do nothing;
 -- Not-connected needs no customer response; the existing legacy validator expects a value for literal Confirm.
 perform public.jf_followup_outcomes130(target_shop,cid,label,null,coalesce(details->>'status_note162',''),cs,case when cs='connected' then response else 'intermediate' end);
 if cs='not_connected' then update public.jf_followups set customer_status130=null where shop_id=target_shop and customer_id=cid;end if;
 insert into jioflow_private.confirm_orders162(order_id) values(oid) on conflict do nothing;
 delete from jioflow_private.confirm_context162 where tx=txid_current() and shop_id=target_shop and customer_id=cid;
 return oid;
end $$;
revoke all on function public.jf_save_order(uuid,uuid,jsonb),public.jf_followup_status(uuid,uuid,text,timestamptz,text) from public,anon;
grant execute on function public.jf_save_order(uuid,uuid,jsonb),public.jf_followup_status(uuid,uuid,text,timestamptz,text) to authenticated;
-- Old status-only confirmations are retained in an audit backup, then returned to an active processing label.
create table if not exists jioflow_private.confirm_legacy_backup162(customer_id uuid primary key,shop_id uuid,workflow_label text,saved_at timestamptz default now());
revoke all on jioflow_private.confirm_legacy_backup162 from public,anon,authenticated;
insert into jioflow_private.confirm_legacy_backup162(customer_id,shop_id,workflow_label)
select c.id,c.shop_id,c.workflow_label from public.jf_customers c where c.archived_at is null and c.workflow_label=any(jioflow_private.confirmed_labels149(c.shop_id)) and not exists(select 1 from public.jf_orders o where o.shop_id=c.shop_id and o.customer_id=c.id and o.archived_at is null and o.status<>'draft') on conflict do nothing;
update public.jf_customers c set workflow_label=coalesce((select x->>'name' from jsonb_array_elements(case when c.permanent then jioflow_private.permanent_status_definitions(c.shop_id) else jioflow_private.status_definitions(c.shop_id) end) x where x->>'kind'='processing' and coalesce((x->>'active')::boolean,false) order by x->>'id' limit 1),'Processing')
where c.archived_at is null and c.workflow_label=any(jioflow_private.confirmed_labels149(c.shop_id)) and not exists(select 1 from public.jf_orders o where o.shop_id=c.shop_id and o.customer_id=c.id and o.archived_at is null and o.status<>'draft');
create or replace function jioflow_private.confirm_order_guard162() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='UPDATE' and new.workflow_label is not distinct from old.workflow_label then return new;end if;
 if new.workflow_label=any(jioflow_private.confirmed_labels149(new.shop_id)) and (not exists(select 1 from jioflow_private.confirm_context162 t where t.tx=txid_current() and t.shop_id=new.shop_id and t.customer_id=new.id) or not exists(select 1 from public.jf_orders o where o.shop_id=new.shop_id and o.customer_id=new.id and o.archived_at is null and o.status<>'draft')) then raise exception 'Save an order before confirming this customer.';end if;return new;
end $$;
revoke all on function jioflow_private.confirm_order_guard162() from public,anon,authenticated;
drop trigger if exists confirm_order_guard162 on public.jf_customers;
create trigger confirm_order_guard162 before insert or update of workflow_label on public.jf_customers for each row execute function jioflow_private.confirm_order_guard162();
commit;
