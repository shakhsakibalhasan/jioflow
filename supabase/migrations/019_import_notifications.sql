-- Apply once after 018. Bounded import transactions and real event notifications.
begin;
do $$begin if not exists(select 1 from public.jf_schema_versions where version='018_finance_agent_totals') then raise exception 'Apply migration 018 first.';end if;end$$;
create function public.jf_save_customer_batch(target_shop uuid,customers jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare row jsonb;saved integer:=0;
begin
 if not jioflow_private.has_permission(target_shop,'import') or not jioflow_private.has_permission(target_shop,'assign') or not jioflow_private.reads_staff_operations(target_shop) then raise exception 'Import permission required.' using errcode='42501';end if;
 if jsonb_typeof(customers) is distinct from 'array' or jsonb_array_length(customers) not between 1 and 100 then raise exception 'Send 1–100 customers per transaction.' using errcode='22023';end if;
 for row in select * from jsonb_array_elements(customers) loop perform public.jf_save_customer(target_shop,null,row);saved:=saved+1;end loop;
 return jsonb_build_object('saved',saved);
end $$;
revoke all on function public.jf_save_customer_batch(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.jf_save_customer_batch(uuid,jsonb) to authenticated;
create table jioflow_private.daily_leaders(shop_id uuid references public.jf_shops(id) on delete cascade,day date not null,membership_id uuid not null,primary key(shop_id,day));
revoke all on jioflow_private.daily_leaders from public,anon,authenticated;
create function jioflow_private.negative_followup_notice() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.call_outcome='negative' and (tg_op='INSERT' or old.call_outcome is distinct from new.call_outcome) then
  insert into public.jf_notifications(shop_id,kind,title,body,reference_id) values(new.shop_id,'negative_followup','Negative customer response','A follow-up needs review. Open Follow-ups to see the customer and latest note.',new.customer_id);
   insert into public.jf_notifications(shop_id,recipient_id,kind,title,body,reference_id) select new.shop_id,m.user_id,'negative_followup','Negative customer response','Review your customer follow-up and next action.',new.customer_id from public.jf_customers c join public.jf_memberships m on m.id=c.assigned_membership_id where c.id=new.customer_id and c.shop_id=new.shop_id and m.status='active';
 end if;return new;
end $$;
create trigger jf_negative_followup_notice after insert or update of call_outcome on public.jf_followups for each row execute function jioflow_private.negative_followup_notice();
create function jioflow_private.verification_notice() returns trigger language plpgsql security definer set search_path='' as $$
declare sid uuid; title text;
begin
 if new.managed_agent or new.email_verified_at is not distinct from old.email_verified_at and new.pending_email is not distinct from old.pending_email then return new;end if;
 select id into sid from public.jf_shops where owner_id=new.id limit 1;
 if sid is null then select shop_id into sid from public.jf_memberships where user_id=new.id and status<>'removed' limit 1;end if;
 title:=case when new.pending_email<>'' then 'Email verification pending' when new.email_verified_at is not null then 'Email verified' else 'Email verification required' end;
 insert into public.jf_notifications(shop_id,recipient_id,kind,title,body,reference_id) values(sid,new.id,'verification',title,'Open your profile to review email verification.',new.id);
 if sid is not null then insert into public.jf_notifications(shop_id,kind,title,body,reference_id) values(sid,'verification',title,new.full_name||' · account verification updated.',new.id);end if;
 return new;
end $$;
create trigger jf_verification_notice after update of email_verified_at,pending_email on public.jf_profiles for each row execute function jioflow_private.verification_notice();
create function jioflow_private.top_performer_notice() returns trigger language plpgsql security definer set search_path='' as $$
declare winner uuid;uid uuid;oldwinner uuid;label text;cnt bigint;today date:=(now() at time zone 'Asia/Dhaka')::date;
begin
 -- Serialize leader changes per shop. Reads only today's confirmed orders.
 perform 1 from public.jf_shops where id=new.shop_id for update;
 select o.assigned_membership_id,count(*) into winner,cnt from public.jf_orders o join public.jf_memberships m on m.id=o.assigned_membership_id and m.shop_id=o.shop_id join public.jf_profiles p on p.id=m.user_id where o.shop_id=new.shop_id and o.archived_at is null and o.status not in('draft','cancelled') and o.created_at>=today::timestamp at time zone 'Asia/Dhaka' and o.created_at<(today+1)::timestamp at time zone 'Asia/Dhaka' and m.role='agent' and m.status='active' and p.active group by o.assigned_membership_id order by count(*) desc,sum(o.total) desc,o.assigned_membership_id limit 1;
 if winner is null then delete from jioflow_private.daily_leaders where shop_id=new.shop_id and day=today;return new;end if;
 select membership_id into oldwinner from jioflow_private.daily_leaders where shop_id=new.shop_id and day=today;
 if oldwinner is distinct from winner then
  insert into jioflow_private.daily_leaders(shop_id,day,membership_id) values(new.shop_id,today,winner) on conflict(shop_id,day) do update set membership_id=excluded.membership_id;
  select p.full_name,p.id into label,uid from public.jf_memberships m join public.jf_profiles p on p.id=m.user_id where m.id=winner;
  insert into public.jf_notifications(shop_id,kind,title,body,reference_id) values(new.shop_id,'top_performer','Today’s top performer',label||' leads with '||cnt||' confirmed orders.',winner);
  insert into public.jf_notifications(shop_id,recipient_id,kind,title,body,reference_id) values(new.shop_id,uid,'top_performer','You are today’s top performer','You lead with '||cnt||' confirmed orders.',winner);
 end if;return new;
end $$;
create trigger jf_top_performer_notice after insert or update of status,assigned_membership_id,archived_at on public.jf_orders for each row execute function jioflow_private.top_performer_notice();
revoke all on function jioflow_private.negative_followup_notice(),jioflow_private.verification_notice(),jioflow_private.top_performer_notice() from public,anon,authenticated;
create function public.jf_phone_courier_overview(target_shop uuid,phone text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare normalized text;result jsonb;
begin
 if not jioflow_private.reads_operations(target_shop) or not jioflow_private.has_permission(target_shop,'assign') then raise exception 'Order access required.' using errcode='42501';end if;
 normalized:=jioflow_private.normalize_phone(phone);
 select coalesce(jsonb_agg(to_jsonb(t)),'[]') into result from(select lower(s.courier) courier,count(*) total,count(*) filter(where s.status='delivered') delivered,count(*) filter(where s.status='returned') returned,count(*) filter(where s.status in('pending','booking','booked','in_transit')) pending from public.jf_shipments s join public.jf_orders o on o.id=s.order_id and o.shop_id=s.shop_id where s.shop_id=target_shop and o.recipient_phone=normalized and jioflow_private.can_read_order(target_shop,o.id) group by lower(s.courier))t;
 return jsonb_build_object('local',result,'providers',jsonb_build_array(jsonb_build_object('id','steadfast','name','Steadfast','connected',false),jsonb_build_object('id','pathao','name','Pathao','connected',false)));
end $$;
revoke all on function public.jf_phone_courier_overview(uuid,text) from public,anon,authenticated;
grant execute on function public.jf_phone_courier_overview(uuid,text) to authenticated;

create table public.jf_platform_layouts(user_id uuid not null references public.jf_profiles(id) on delete cascade,page text not null check(length(page) between 1 and 120),value jsonb not null,primary key(user_id,page));
alter table public.jf_platform_layouts enable row level security;
revoke all on public.jf_platform_layouts from public,anon,authenticated;
create function public.jf_platform_layout(page_key text,layout_value jsonb default null) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501';end if;
 if length(page_key) not between 1 and 120 then raise exception 'Invalid page.';end if;
 if layout_value is not null then
  if jsonb_typeof(layout_value) is distinct from 'object' or octet_length(layout_value::text)>100000 then raise exception 'Invalid layout.';end if;
  insert into public.jf_platform_layouts(user_id,page,value) values(auth.uid(),page_key,layout_value) on conflict(user_id,page) do update set value=excluded.value;
 end if;
 return coalesce((select value from public.jf_platform_layouts where user_id=auth.uid() and page=page_key),'{}');
end $$;
revoke all on function public.jf_platform_layout(text,jsonb) from public,anon,authenticated;grant execute on function public.jf_platform_layout(text,jsonb) to authenticated;

insert into public.jf_schema_versions(version) values('019_import_notifications');commit;
