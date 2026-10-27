begin;
do $$begin if not exists(select 1 from public.jf_schema_versions where version='043_followup_amount') then raise exception 'Apply Database61.sql first.';end if;end$$;
alter table public.jf_followups add column callback_agent_id uuid references public.jf_profiles(id),add column callback_key uuid;
alter table public.jf_notifications add column callback_at timestamptz,add column callback_key uuid,add column popup_seen_at timestamptz;
create unique index jf_callback_notification_once on public.jf_notifications(callback_key) where kind='callback_due';
create index jf_callback_agent_due on public.jf_followups(callback_agent_id,callback_at) where status='callback' and callback_key is not null;
-- Retain only schedules last saved by their currently assigned Agent.
update public.jf_followups f set callback_agent_id=f.updated_by,callback_key=gen_random_uuid() from public.jf_customers c join public.jf_memberships m on m.id=c.assigned_membership_id and m.shop_id=c.shop_id where f.shop_id=c.shop_id and f.customer_id=c.id and f.status='callback' and f.callback_at is not null and f.updated_by=m.user_id and m.role='agent' and m.status='active' and c.archived_at is null;
create function jioflow_private.callback_owner() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status<>'callback' or new.callback_at is null then new.callback_agent_id:=null;new.callback_key:=null;return new;end if;
 if tg_op='UPDATE' then if old.status='callback' and old.callback_at is not distinct from new.callback_at then new.callback_agent_id:=old.callback_agent_id;new.callback_key:=old.callback_key;return new;end if;end if;
 new.callback_agent_id:=null;new.callback_key:=null;
 if new.updated_by=auth.uid() and exists(select 1 from public.jf_memberships m join public.jf_profiles p on p.id=m.user_id where m.shop_id=new.shop_id and m.user_id=auth.uid() and m.role='agent' and m.status='active' and p.active and p.deleted_at is null and coalesce(p.platform_role,'')<>'creator') then new.callback_agent_id:=auth.uid();new.callback_key:=gen_random_uuid();end if;
 return new;
end$$;
create function jioflow_private.callback_notice() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='callback' and new.callback_key is not null then
  insert into public.jf_notifications(shop_id,recipient_id,kind,title,body,reference_id,created_at,callback_at,callback_key)
  select new.shop_id,new.callback_agent_id,'callback_due','Follow-up reminder',coalesce(nullif(c.full_name,''),'Customer')||' · '||c.phone||' — your scheduled follow-up is due.',new.customer_id,new.callback_at,new.callback_at,new.callback_key from public.jf_customers c where c.shop_id=new.shop_id and c.id=new.customer_id
  on conflict(callback_key) where kind='callback_due' do nothing;
 end if;return new;
end$$;
revoke all on function jioflow_private.callback_owner(),jioflow_private.callback_notice() from public,anon,authenticated;
create trigger jf_callback_owner before insert or update on public.jf_followups for each row execute function jioflow_private.callback_owner();
create trigger jf_callback_notice after insert or update on public.jf_followups for each row execute function jioflow_private.callback_notice();
insert into public.jf_notifications(shop_id,recipient_id,kind,title,body,reference_id,created_at,callback_at,callback_key)
select f.shop_id,f.callback_agent_id,'callback_due','Follow-up reminder',coalesce(nullif(c.full_name,''),'Customer')||' · '||c.phone||' — your scheduled follow-up is due.',c.id,f.callback_at,f.callback_at,f.callback_key from public.jf_followups f join public.jf_customers c on c.shop_id=f.shop_id and c.id=f.customer_id where f.callback_key is not null;
create function jioflow_private.callback_notice_visible(notification uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.jf_notifications n join public.jf_followups f on f.shop_id=n.shop_id and f.customer_id=n.reference_id and f.callback_key=n.callback_key join public.jf_customers c on c.shop_id=f.shop_id and c.id=f.customer_id join public.jf_memberships m on m.shop_id=f.shop_id and m.user_id=f.callback_agent_id join public.jf_profiles p on p.id=m.user_id join public.jf_shops s on s.id=f.shop_id where n.id=notification and n.recipient_id=auth.uid() and f.callback_agent_id=auth.uid() and f.status='callback' and f.callback_at<=now() and f.callback_at=n.callback_at and m.role='agent' and m.status='active' and p.active and p.deleted_at is null and coalesce(p.platform_role,'')<>'creator' and c.archived_at is null and s.active and s.archived_at is null and jioflow_private.can_read_customer(c.shop_id,c.id));
$$;
revoke all on function jioflow_private.callback_notice_visible(uuid) from public,anon,authenticated;
create function public.jf_callback_reminders(target_shop uuid default null) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare upcoming timestamptz;due jsonb;
begin
 if not coalesce(jioflow_private.session_allowed(),false) then raise exception 'Sign in required.' using errcode='42501';end if;
 select min(f.callback_at) into upcoming from public.jf_followups f join public.jf_memberships m on m.user_id=f.callback_agent_id and m.shop_id=f.shop_id join public.jf_profiles p on p.id=m.user_id join public.jf_customers c on c.id=f.customer_id and c.shop_id=f.shop_id where f.callback_agent_id=auth.uid() and m.role='agent' and m.status='active' and p.active and coalesce(p.platform_role,'')<>'creator' and f.status='callback' and f.callback_at>now() and f.callback_key is not null and (target_shop is null or f.shop_id=target_shop) and jioflow_private.can_read_customer(c.shop_id,c.id);
 select coalesce(jsonb_agg(to_jsonb(t) order by callback_at),'[]'::jsonb) into due from(select n.id,n.shop_id,n.reference_id customer_id,n.callback_at,n.popup_seen_at,c.full_name,c.phone from public.jf_notifications n join public.jf_customers c on c.shop_id=n.shop_id and c.id=n.reference_id where n.kind='callback_due' and (target_shop is null or n.shop_id=target_shop) and jioflow_private.callback_notice_visible(n.id) and not exists(select 1 from public.jf_notification_dismissals d where d.notification_id=n.id and d.user_id=auth.uid()) order by (n.popup_seen_at is not null),n.callback_at,n.id limit 100)t;
 return jsonb_build_object('server_time',now(),'next_at',upcoming,'due',due);
end$$;
create function public.jf_callback_popup_ack(notification uuid) returns boolean language plpgsql security definer set search_path='' as $$
begin
 if not coalesce(jioflow_private.session_allowed(),false) then raise exception 'Sign in required.' using errcode='42501';end if;
 update public.jf_notifications set popup_seen_at=coalesce(popup_seen_at,now()) where id=notification and kind='callback_due' and recipient_id=auth.uid();if not found then raise exception 'Reminder access denied.' using errcode='42501';end if;return true;
end$$;
revoke all on function public.jf_callback_reminders(uuid),public.jf_callback_popup_ack(uuid) from public,anon;
grant execute on function public.jf_callback_reminders(uuid),public.jf_callback_popup_ack(uuid) to authenticated;
create or replace function public.jf_notifications_feed(target_shop uuid default null) returns jsonb language sql stable security definer set search_path='' as $$
 with visible as materialized(select n.*,exists(select 1 from public.jf_notification_reads r where r.notification_id=n.id and r.user_id=auth.uid()) is_read from public.jf_notifications n where (target_shop is null or n.shop_id=target_shop or n.shop_id is null) and jioflow_private.notification_visible(n.shop_id,n.recipient_id) and (n.kind<>'callback_due' or jioflow_private.callback_notice_visible(n.id)) and not exists(select 1 from public.jf_notification_dismissals d where d.notification_id=n.id and d.user_id=auth.uid()))
 select jsonb_build_object('shop_scope',target_shop,'items',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from(select * from visible order by created_at desc,id desc limit 50)x),'[]'::jsonb),'unread_count',(select count(*) from visible where not is_read));
$$;
create or replace function public.jf_notification_action(action text,notification uuid default null,target_shop uuid default null) returns integer language plpgsql security definer set search_path='' as $$
declare changed integer;
begin
 if not jioflow_private.session_allowed() then raise exception 'Sign in required.' using errcode='42501';end if;
 if action='read_all' then
  insert into public.jf_notification_reads(notification_id,user_id) select n.id,auth.uid() from public.jf_notifications n where (target_shop is null or n.shop_id=target_shop or n.shop_id is null) and jioflow_private.notification_visible(n.shop_id,n.recipient_id) and (n.kind<>'callback_due' or jioflow_private.callback_notice_visible(n.id)) and not exists(select 1 from public.jf_notification_dismissals d where d.notification_id=n.id and d.user_id=auth.uid()) on conflict do nothing;
 elsif action='delete' then
  if not exists(select 1 from public.jf_notifications n where n.id=notification and (target_shop is null or n.shop_id=target_shop or n.shop_id is null) and jioflow_private.notification_visible(n.shop_id,n.recipient_id) and (n.kind<>'callback_due' or jioflow_private.callback_notice_visible(n.id))) then raise exception 'Notification access denied.' using errcode='42501';end if;
  insert into public.jf_notification_dismissals(notification_id,user_id) values(notification,auth.uid()) on conflict do nothing;
 else raise exception 'Unknown inbox action.';end if;
 get diagnostics changed=row_count;return changed;
end $$;
revoke all on function public.jf_notification_action(text,uuid,uuid) from public,anon,authenticated;
grant execute on function public.jf_notification_action(text,uuid,uuid) to authenticated;
insert into public.jf_schema_versions(version) values('044_callback_reminders') on conflict do nothing;
commit;
