begin;
create or replace function jioflow_private.jf_latest_order_status103(target_shop uuid)
returns table(customer_id uuid,order_status text)
language plpgsql stable security definer set search_path='' as $latest$
declare staff103 boolean;agent103 uuid;
begin
 staff103:=coalesce(jioflow_private.reads_staff_operations(target_shop),false);agent103:=jioflow_private.agent_member(target_shop);
 if not staff103 and agent103 is null then raise exception 'Workspace access required.' using errcode='42501';end if;
 return query select distinct on(m.cid) m.cid,m.status from (
 select h.customer_id cid,nullif(trim(public.jf_import_filter_value(h.details,'status')),'') status,h.import_order_date102 d,h.updated_at t,h.id
 from public.jf_order_history h join public.jf_customers c on c.shop_id=h.shop_id and c.id=h.customer_id
 where h.shop_id=target_shop and c.archived_at is null and (staff103 or c.assigned_membership_id=agent103)
 union all select z.customer_id,z.status::text,(z.created_at at time zone 'Asia/Dhaka')::date,z.created_at,z.id
 from public.jf_orders z join public.jf_customers c on c.shop_id=z.shop_id and c.id=z.customer_id
 where z.shop_id=target_shop and z.archived_at is null and c.archived_at is null and (staff103 or c.assigned_membership_id=agent103)
 and (staff103 or z.assigned_membership_id=agent103 or z.entered_by=auth.uid())
 ) m order by m.cid,m.d desc nulls last,m.t desc,m.id desc;
end $latest$;
revoke all on function jioflow_private.jf_latest_order_status103(uuid) from public,anon;
grant execute on function jioflow_private.jf_latest_order_status103(uuid) to authenticated;
create or replace function public.jf_customer_note103(target_shop uuid,target_customer uuid,note_text text) returns jsonb
language plpgsql security definer set search_path='' as $note$
declare saved public.jf_notes%rowtype;
begin
 if not coalesce(jioflow_private.session_allowed(),false) or not coalesce(jioflow_private.has_permission(target_shop,'assign'),false) or not coalesce(jioflow_private.can_read_customer(target_shop,target_customer),false) or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null) then raise exception 'Follow-up access denied.' using errcode='42501';end if;
 perform 1 from public.jf_customers c where c.shop_id=target_shop and c.id=target_customer and c.archived_at is null for update;
 if not found then raise exception 'Customer not found.';end if;
 if length(trim(coalesce(note_text,''))) not between 1 and 10000 then raise exception 'Write a note between 1 and 10000 characters.';end if;
 insert into public.jf_notes(shop_id,customer_id,body,author_id) values(target_shop,target_customer,trim(note_text),auth.uid()) returning * into saved;
 return jsonb_build_object('id',saved.id,'body',saved.body,'created_at',saved.created_at);
end $note$;
revoke all on function public.jf_customer_note103(uuid,uuid,text) from public,anon;
grant execute on function public.jf_customer_note103(uuid,uuid,text) to authenticated;
do $patch$
declare r record;d text;
begin
 for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.prokind='f' and p.proname like 'jf_%' loop
 d:=pg_get_functiondef(r.oid);
 if position('with matched102 as materialized(' in d)>0 and position('latest103 as materialized(' in d)=0 then
 d:=replace(d,'with matched102 as materialized(', 'with latest103 as materialized(select * from jioflow_private.jf_latest_order_status103(target_shop)),matched102 as materialized(');
 d:=replace(d,'from(select c.*,jsonb_build_object(', 'from(select c.*,ls.order_status as latest_order_status,jsonb_build_object(');
 d:=replace(d,'from c left join matched102 m on m.customer_id=c.id order by','from c left join matched102 m on m.customer_id=c.id left join latest103 ls on ls.customer_id=c.id order by');
 execute d;
 end if;
 end loop;
end $patch$;
commit;
