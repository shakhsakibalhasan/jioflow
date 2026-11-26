-- Personal inbox actions; deleting a notification never removes another user's copy.
begin;
do $$begin if not exists(select 1 from public.jf_schema_versions where version='021_inline_tab_counts') then raise exception 'Apply migration 021 first.';end if;end$$;
create table public.jf_notification_dismissals(notification_id uuid not null references public.jf_notifications(id),user_id uuid not null references public.jf_profiles(id),dismissed_at timestamptz not null default now(),primary key(notification_id,user_id));
alter table public.jf_notification_dismissals enable row level security;
revoke all on public.jf_notification_dismissals from public,anon,authenticated;
create or replace function public.jf_notifications_feed(target_shop uuid default null) returns jsonb language sql stable security definer set search_path='' as $$
 with visible as materialized(select n.*,exists(select 1 from public.jf_notification_reads r where r.notification_id=n.id and r.user_id=auth.uid()) is_read from public.jf_notifications n where (target_shop is null or n.shop_id=target_shop or n.shop_id is null) and jioflow_private.notification_visible(n.shop_id,n.recipient_id) and not exists(select 1 from public.jf_notification_dismissals d where d.notification_id=n.id and d.user_id=auth.uid()))
 select jsonb_build_object('shop_scope',target_shop,'items',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from(select * from visible order by created_at desc,id desc limit 50)x),'[]'::jsonb),'unread_count',(select count(*) from visible where not is_read));
$$;
create function public.jf_notification_action(action text,notification uuid default null,target_shop uuid default null) returns integer language plpgsql security definer set search_path='' as $$
declare changed integer;
begin
 if not jioflow_private.session_allowed() then raise exception 'Sign in required.' using errcode='42501';end if;
 if action='read_all' then
  insert into public.jf_notification_reads(notification_id,user_id) select n.id,auth.uid() from public.jf_notifications n where (target_shop is null or n.shop_id=target_shop or n.shop_id is null) and jioflow_private.notification_visible(n.shop_id,n.recipient_id) and not exists(select 1 from public.jf_notification_dismissals d where d.notification_id=n.id and d.user_id=auth.uid()) on conflict do nothing;
 elsif action='delete' then
  if not exists(select 1 from public.jf_notifications n where n.id=notification and (target_shop is null or n.shop_id=target_shop or n.shop_id is null) and jioflow_private.notification_visible(n.shop_id,n.recipient_id)) then raise exception 'Notification access denied.' using errcode='42501';end if;
  insert into public.jf_notification_dismissals(notification_id,user_id) values(notification,auth.uid()) on conflict do nothing;
 else raise exception 'Unknown inbox action.';end if;
 get diagnostics changed=row_count;return changed;
end $$;
revoke all on function public.jf_notification_action(text,uuid,uuid) from public,anon,authenticated;
grant execute on function public.jf_notification_action(text,uuid,uuid) to authenticated;
insert into public.jf_schema_versions(version) values('022_notification_inbox_actions');commit;
