begin;
do $$begin if not exists(select 1 from public.jf_schema_versions where version='036_manual_couriers') then raise exception 'Apply Database55.sql first.';end if;end$$;
-- Counts only this business's live orders; no customer contact data is exposed.
create or replace function public.jf_performer_periods(target_shop uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;local_now timestamp:=now() at time zone 'Asia/Dhaka';may_profit boolean;
begin
 if not coalesce(jioflow_private.session_allowed(),false) or not coalesce(jioflow_private.reads_operations(target_shop),false) then raise exception 'Workspace access required.' using errcode='42501';end if;
 if not exists(select 1 from public.jf_shops where id=target_shop and active and paused_at is null and archived_at is null) then raise exception 'Business unavailable.' using errcode='42501';end if;
 may_profit:=coalesce(jioflow_private.has_permission(target_shop,'profit'),false) and jioflow_private.agent_member(target_shop) is null;
 with periods as(select 'daily' kind,date_trunc('day',local_now) at time zone 'Asia/Dhaka' starts,(date_trunc('day',local_now)+interval '1 day') at time zone 'Asia/Dhaka' ends union all select 'yesterday',(date_trunc('day',local_now)-interval '1 day') at time zone 'Asia/Dhaka',date_trunc('day',local_now) at time zone 'Asia/Dhaka' union all select 'monthly',date_trunc('month',local_now) at time zone 'Asia/Dhaka',(date_trunc('month',local_now)+interval '1 month') at time zone 'Asia/Dhaka'),
 orders as(select o.*,case when may_profit then coalesce(f.product_cost,(select case when count(*)>0 and count(*)=count(pc.unit_cost) then sum(i.quantity*pc.unit_cost) end from public.jf_order_items i left join public.jf_product_costs pc on pc.shop_id=i.shop_id and pc.product_id=i.product_id where i.shop_id=o.shop_id and i.order_id=o.id)) end cost,
 coalesce(f.courier_charge,o.delivery_charge)+coalesce(f.cod_fee,0)+coalesce(f.packaging_cost,0)+coalesce(f.return_cost,0)+coalesce(f.other_cost,0) fees from public.jf_orders o left join public.jf_order_finance f on f.shop_id=o.shop_id and f.order_id=o.id where o.shop_id=target_shop and o.archived_at is null and o.created_at>=least(date_trunc('month',local_now),date_trunc('day',local_now)-interval '1 day') at time zone 'Asia/Dhaka' and o.created_at<now()+interval '1 second'),
 totals as(select w.kind,m.id membership_id,p.full_name,p.avatar_path,count(*) filter(where o.status not in('draft','cancelled')) confirmed,count(*) filter(where o.status='delivered') delivered,count(*) filter(where o.status='returned') returned,count(*) filter(where o.status='cancelled') cancelled,coalesce(sum(o.total) filter(where o.status not in('draft','cancelled')),0) sales,
 case when may_profit and count(*) filter(where o.status not in('draft','cancelled'))=count(o.cost) filter(where o.status not in('draft','cancelled')) then coalesce(sum(o.total-o.cost-o.fees) filter(where o.status not in('draft','cancelled')),0) end profit
 from periods w join orders o on o.created_at>=w.starts and o.created_at<w.ends join public.jf_memberships m on m.id=o.assigned_membership_id and m.shop_id=target_shop and m.role='agent' and m.status='active' join public.jf_profiles p on p.id=m.user_id and p.active and p.deleted_at is null group by w.kind,m.id,p.full_name,p.avatar_path),
 ranked as(select t.*,row_number() over(partition by kind order by confirmed desc,sales desc,membership_id) rank,case when sum(confirmed) over(partition by kind)>0 then round(100.0*confirmed/sum(confirmed) over(partition by kind),1) else 0 end contribution from totals t where confirmed>0)
 select jsonb_build_object('day',local_now::date,'month',to_char(local_now,'YYYY-MM'),'yesterday_day',(local_now::date-1),'timezone','Asia/Dhaka','ranking','Confirmed orders, then sales value','can_profit',may_profit,'daily',coalesce((select jsonb_agg(to_jsonb(r)-'kind' order by rank) from ranked r where kind='daily' and rank<=3),'[]'),'yesterday',coalesce((select jsonb_agg(to_jsonb(r)-'kind' order by rank) from ranked r where kind='yesterday' and rank<=3),'[]'),'monthly',coalesce((select jsonb_agg(to_jsonb(r)-'kind' order by rank) from ranked r where kind='monthly' and rank<=3),'[]')) into result;
 return result;
end$$;
revoke all on function public.jf_performer_periods(uuid) from public,anon;
grant execute on function public.jf_performer_periods(uuid) to authenticated;
insert into public.jf_schema_versions(version) values('037_performer_periods') on conflict do nothing;
commit;

begin;
create or replace function jioflow_private.status_definitions(target_shop uuid) returns jsonb language sql stable security definer set search_path='' as $$select coalesce((select value->'status_definitions' from public.jf_workspace_settings where shop_id=target_shop),'[{"id":"default-0","name":"Processing","color":"#64748b","kind":"processing","days":0,"active":true},{"id":"default-1","name":"Confirm","color":"#16834a","kind":"confirm","days":0,"active":true},{"id":"default-2","name":"Refuse","color":"#c43f49","kind":"negative","days":0,"active":true},{"id":"default-3","name":"No Response","color":"#6661cb","kind":"no_answer","days":0,"active":true},{"id":"default-4","name":"Don’t Call Again","color":"#b93643","kind":"negative","days":0,"active":true},{"id":"default-5","name":"Order Recently","color":"#6377bd","kind":"processing","days":0,"active":true},{"id":"default-6","name":"Busy","color":"#7163b8","kind":"busy","days":0,"active":true},{"id":"default-7","name":"Schedule","color":"#af8219","kind":"schedule","days":0,"active":true},{"id":"default-8","name":"Problem Solve","color":"#16834a","kind":"positive","days":0,"active":true},{"id":"default-9","name":"Interested","color":"#2b8c63","kind":"positive","days":0,"active":true},{"id":"default-10","name":"Not Interested","color":"#bd3b49","kind":"negative","days":0,"active":true},{"id":"default-11","name":"For Relative","color":"#6b71bb","kind":"processing","days":0,"active":true},{"id":"default-12","name":"Irregular","color":"#a98519","kind":"processing","days":0,"active":true},{"id":"default-13","name":"FL - 7 Days Later","color":"#4e8b4d","kind":"schedule","days":7,"active":true},{"id":"default-14","name":"FL - 15 Days Later","color":"#4e8b4d","kind":"schedule","days":15,"active":true},{"id":"default-15","name":"FL - 1 Month Later","color":"#4e8b4d","kind":"schedule","days":30,"active":true},{"id":"default-16","name":"FL - 2 Months Later","color":"#4e8b4d","kind":"schedule","days":60,"active":true},{"id":"default-17","name":"FL - 3 Months Later","color":"#4e8b4d","kind":"schedule","days":90,"active":true}]'::jsonb)$$;
revoke all on function jioflow_private.status_definitions(uuid) from public,anon,authenticated;
create or replace function jioflow_private.permanent_status_definitions(target_shop uuid) returns jsonb language sql stable security definer set search_path='' as $$select coalesce((select value->'permanent_status_definitions' from public.jf_workspace_settings where shop_id=target_shop),'[{"id":"permanent-new","name":"New","color":"#64748b","kind":"processing","days":0,"active":true}]'::jsonb)$$;
revoke all on function jioflow_private.permanent_status_definitions(uuid) from public,anon,authenticated;
create or replace function public.jf_status_settings(target_shop uuid,statuses_value jsonb default null,tags_value jsonb default null,permanent_value jsonb default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare value jsonb;old jsonb;item jsonb;prev jsonb;k text;can_edit boolean;
begin
 if not coalesce(jioflow_private.session_allowed(),false) or not coalesce(jioflow_private.reads_operations(target_shop),false) or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null) then raise exception 'Workspace access required.' using errcode='42501';end if;
 can_edit:=coalesce(jioflow_private.has_permission(target_shop,'settings'),false) and jioflow_private.agent_member(target_shop) is null;
 if statuses_value is not null or tags_value is not null or permanent_value is not null then
  if not can_edit then raise exception 'Status configuration permission required.' using errcode='42501';end if;
  perform 1 from public.jf_shops where id=target_shop for update;
  foreach k in array array['status_definitions','tag_definitions','permanent_status_definitions'] loop
   value:=case when k='status_definitions' then statuses_value when k='tag_definitions' then tags_value else permanent_value end;
   if value is null then continue;end if;
   if jsonb_typeof(value) is distinct from 'array' or octet_length(value::text)>100000 then raise exception 'Invalid definitions.';end if;
   if exists(select 1 from jsonb_array_elements(value) x where jsonb_typeof(x) is distinct from 'object' or coalesce(x->>'id','') !~ '^[a-zA-Z0-9-]{1,80}$' or length(trim(coalesce(x->>'name',''))) not between 1 and 120 or coalesce(x->>'color','') !~ '^#[a-fA-F0-9]{6}$' or jsonb_typeof(x->'active') is distinct from 'boolean') then raise exception 'Each definition needs a name, valid color and active flag.';end if;
   if exists(select 1 from jsonb_array_elements(value) x group by x->>'id' having count(*)>1) or exists(select 1 from jsonb_array_elements(value) x where (x->>'active')::boolean group by lower(trim(x->>'name')) having count(*)>1) then raise exception 'Use unique definition names and IDs.';end if;
   if k in ('status_definitions','permanent_status_definitions') then
    if exists(select 1 from jsonb_array_elements(value) x where coalesce(x->>'kind','') not in('processing','confirm','positive','negative','no_answer','busy','schedule') or coalesce(x->>'days','') !~ '^\d{1,4}$' or (x->>'days')::integer not between 0 and 3650) then raise exception 'Invalid status report category or callback days.';end if;
    if (select count(*) from jsonb_array_elements(value) x where (x->>'active')::boolean and x->>'kind'='confirm')>1 or (select count(*) from jsonb_array_elements(value) x where (x->>'active')::boolean and x->>'kind'='schedule' and (x->>'days')::integer=0)>1 then raise exception 'Choose only one Confirm and one scheduled-date status.';end if;
    old:=case when k='permanent_status_definitions' then jioflow_private.permanent_status_definitions(target_shop) else jioflow_private.status_definitions(target_shop) end;
   else select coalesce(s.value->'tag_definitions','[]') into old from public.jf_workspace_settings s where shop_id=target_shop;end if;
   for item in select * from jsonb_array_elements(value) loop
    select x into prev from jsonb_array_elements(coalesce(old,'[]')) x where x->>'id'=item->>'id';
    if prev is not null and prev->>'name' is distinct from item->>'name' then
     if k in('status_definitions','permanent_status_definitions') then update public.jf_customers set workflow_label=trim(item->>'name') where shop_id=target_shop and workflow_label=prev->>'name' and permanent=(k='permanent_status_definitions');
     else update public.jf_customers set unassignment_tag=trim(item->>'name') where shop_id=target_shop and unassignment_tag=prev->>'name';end if;
    end if;
   end loop;
   insert into public.jf_workspace_settings(shop_id,value) values(target_shop,jsonb_build_object(k,value,case when k='status_definitions' then 'statuses' when k='tag_definitions' then 'tags' else 'permanent_statuses' end,coalesce((select jsonb_agg(trim(x->>'name')) from jsonb_array_elements(value) x where (x->>'active')::boolean),'[]'))) on conflict(shop_id) do update set value=public.jf_workspace_settings.value||excluded.value,updated_at=now();
  end loop;
 end if;
 return jsonb_build_object('can_configure',can_edit,'statuses',jioflow_private.status_definitions(target_shop),'permanent_statuses',jioflow_private.permanent_status_definitions(target_shop),'tags',coalesce((select s.value->'tag_definitions' from public.jf_workspace_settings s where shop_id=target_shop),'[{"id": "tag-0", "name": "Reassign", "color": "#6366d1", "active": true}, {"id": "tag-1", "name": "Agent Inactive", "color": "#b78317", "active": true}, {"id": "tag-2", "name": "Customer Unreachable", "color": "#8560b8", "active": true}, {"id": "tag-3", "name": "Wrong Number", "color": "#c1454b", "active": true}, {"id": "tag-4", "name": "Follow-up Later", "color": "#16978a", "active": true}, {"id": "tag-5", "name": "Already Follow-up", "color": "#21864d", "active": true}, {"id": "tag-6", "name": "3 Month No Response", "color": "#528e36", "active": true}, {"id": "tag-7", "name": "6 Month No Response", "color": "#8e9421", "active": true}, {"id": "tag-8", "name": "Cancel Data", "color": "#bb4778", "active": true}, {"id": "tag-9", "name": "For 1st Attempt", "color": "#6366d1", "active": true}, {"id": "tag-10", "name": "For 2nd Attempt", "color": "#6366d1", "active": true}, {"id": "tag-11", "name": "For 3rd Attempt", "color": "#6366d1", "active": true}]'::jsonb));
end$$;
revoke all on function public.jf_status_settings(uuid,jsonb,jsonb,jsonb) from public,anon;
grant execute on function public.jf_status_settings(uuid,jsonb,jsonb,jsonb) to authenticated;
create or replace function public.jf_followup_status(target_shop uuid,customer_id uuid,status_label text,callback_time timestamptz default null,note_text text default '') returns uuid language plpgsql security definer set search_path='' as $$
declare fid uuid;next_status text:='pending';outcome text:='intermediate';definition jsonb;days integer;
begin
 if not coalesce(jioflow_private.session_allowed(),false) or not coalesce(jioflow_private.has_permission(target_shop,'assign'),false) or not coalesce(jioflow_private.can_read_customer(target_shop,customer_id),false) or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null) then raise exception 'Follow-up access denied.' using errcode='42501';end if;
 select x into definition from jsonb_array_elements(case when (select c.permanent from public.jf_customers c where c.shop_id=target_shop and c.id=customer_id) then jioflow_private.permanent_status_definitions(target_shop) else jioflow_private.status_definitions(target_shop) end) x where x->>'name'=status_label and (x->>'active')::boolean;
 if definition is null then raise exception 'Choose an active follow-up status.';end if;
 perform 1 from public.jf_customers c where c.shop_id=target_shop and c.id=customer_id and c.archived_at is null for update;
 if not found then raise exception 'Customer not found.';end if;
 case definition->>'kind'
 when 'confirm' then next_status:='completed';outcome:='positive';
 when 'negative' then next_status:='cancelled';outcome:='negative';
 when 'positive' then outcome:='positive';
 when 'no_answer' then outcome:='no_answer';
 when 'busy' then outcome:='busy';
 when 'schedule' then next_status:='callback';outcome:='connected';days:=coalesce((definition->>'days')::integer,0);if days>0 and callback_time is null then callback_time:=now()+days*interval '1 day';end if;
 else null;end case;
 if next_status='callback' and callback_time is null then raise exception 'Select a callback date and time.';end if;
 fid:=public.jf_record_followup(target_shop,customer_id,next_status,outcome,callback_time,note_text);
 update public.jf_customers c set workflow_label=status_label,updated_at=now() where c.shop_id=target_shop and c.id=customer_id;
 return fid;
end$$;
insert into public.jf_schema_versions(version) values('038_custom_statuses_tags') on conflict do nothing;
commit;
