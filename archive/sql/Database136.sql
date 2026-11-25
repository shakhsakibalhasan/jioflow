begin;
alter table public.jf_history_jobs add column if not exists expected_rows136 integer;
-- Process each uploaded chunk immediately, rather than waiting for the full file.
-- The existing import permission checks and shop/job lock run before this branch.
do $patch$
declare d text;
begin
 d:=pg_get_functiondef('public.jf_history_import(uuid,text,jsonb)'::regprocedure);
 if position($s$action='append136'$s$ in d)=0 then
  if position($s$if action='stage' then$s$ in d)=0 then raise exception 'Review changed importer before Update136.';end if;
  d:=replace(d,$s$if action='stage' then$s$,$new$if action='append136' then
  if j.status='cancelled' then raise exception 'This import has been cancelled.';end if;
  if jsonb_typeof(details->'rows') is distinct from 'array' or jsonb_array_length(details->'rows') not between 1 and 500 or coalesce((details->>'offset')::int,-1)<0 or coalesce((details->>'total_rows')::int,0) not between 1 and 1000000 then raise exception 'Invalid streaming import chunk.';end if;
  if (details->>'offset')::int+jsonb_array_length(details->'rows')>(details->>'total_rows')::int then raise exception 'Chunk exceeds total rows.';end if;
  update public.jf_history_jobs set status='uploading',expected_rows136=(details->>'total_rows')::int where id=jid;
  perform public.jf_history_import(target_shop,'stage',details);
  perform public.jf_history_import(target_shop,'ready',jsonb_build_object('job_id',jid));
  perform public.jf_history_import(target_shop,'process',jsonb_build_object('job_id',jid));
  update public.jf_history_jobs set status='uploading' where id=jid and staged<expected_rows136;
  return(select to_jsonb(t) from public.jf_history_jobs t where id=jid);
 elsif action='stage' then$new$);
  d:=replace(d,$s$'total',j.staged,'processed'$s$,$s$'total',coalesce(j.expected_rows136,j.staged),'processed'$s$);
  execute d;
 end if;
end$patch$;
-- Exact-phone read-only lookup within the Agent's approved business.
-- No broad customer-list policy or write permissions are changed.
create or replace function public.jf_phone_lookup136(target_shop uuid,phone_number text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare normalized text;member_id uuid;c public.jf_customers%rowtype;hist jsonb;orders jsonb;agent_name text;
begin
 if not jioflow_private.reads_operations(target_shop) then raise exception 'Business access required.' using errcode='42501';end if;
 member_id:=jioflow_private.agent_member(target_shop);
 if member_id is null and not jioflow_private.manages_shop(target_shop) then raise exception 'Customer lookup is not permitted.' using errcode='42501';end if;
 normalized:=jioflow_private.normalize_phone(phone_number);
 if normalized is null or normalized='' then raise exception 'Enter a complete valid phone number.' using errcode='22023';end if;
 select * into c from public.jf_customers where shop_id=target_shop and phone=normalized and archived_at is null;
 if not found then return jsonb_build_object('customer',null,'history','[]'::jsonb,'orders','[]'::jsonb);end if;
 select p.full_name into agent_name from public.jf_memberships m join public.jf_profiles p on p.id=m.user_id where m.id=c.assigned_membership_id and m.shop_id=target_shop;
 select coalesce(jsonb_agg(jsonb_build_object('id',h.id,'external_id',h.external_id,'details',(select coalesce(jsonb_object_agg(x.key,x.value),'{}') from jsonb_each(h.details) x where x.key in('products','total','status','payment_method','source','site','courier','custom_tag','custom_tag_2','tag','tag2','sku','ordered_at','order_date','order_number','order_id','success_rate','total_orders','customer_rating','taken_by','updated_at'))||jsonb_build_object('original_columns',(select coalesce(jsonb_agg(v),'[]') from jsonb_array_elements(case when jsonb_typeof(h.details->'original_columns')='array' then h.details->'original_columns' else '[]'::jsonb end) v where lower(regexp_replace(v->>'column','[^a-zA-Z0-9]','','g')) in('orderid','ordernumber','invoicenumber','orderdate','status','customername','fullname','phonenumber','phone','mobile','sku','address','shippingaddress','productitems','products','ordertotal','total','paymentmethod','ordersource','source','customtag','customtags','tag','customtag2','tag2','sitename','site','courier','successrate','successratepercent','totalorders','customerrating','createdat','updatedat','employee','takenby'))),'updated_at',h.updated_at) order by h.updated_at desc),'[]') into hist from public.jf_order_history h where h.shop_id=target_shop and h.customer_id=c.id;
 select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'order_number',o.order_number,'recipient_name',o.recipient_name,'recipient_phone',o.recipient_phone,'delivery_address',o.delivery_address,'total',o.total,'status',o.status,'source',o.source,'payment_method',to_jsonb(o)->>'payment_method','created_at',o.created_at,'products135',(select string_agg(i.product_name||' × '||i.quantity::text,', ') from public.jf_order_items i where i.shop_id=target_shop and i.order_id=o.id)) order by o.created_at desc),'[]') into orders from public.jf_orders o where o.shop_id=target_shop and o.customer_id=c.id and o.archived_at is null;
 return jsonb_build_object('customer',jsonb_build_object('id',c.id,'full_name',c.full_name,'phone',c.phone,'address',c.address,'source',c.source,'workflow_label',c.workflow_label,'assigned_membership_id',c.assigned_membership_id),'assigned_name',coalesce(agent_name,'Unassigned'),'own_assignment',coalesce(member_id is null or c.assigned_membership_id=member_id,false),'history',hist,'orders',orders);
end$$;
revoke all on function public.jf_phone_lookup136(uuid,text) from public,anon,authenticated;grant execute on function public.jf_phone_lookup136(uuid,text) to authenticated;
commit;
