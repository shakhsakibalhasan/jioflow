-- Apply after 009. Notification inbox and approval-controlled Agent password resets.
begin;
do $$ begin if not exists(select 1 from public.jf_schema_versions where version='009_agent_sessions_shops') then raise exception 'Apply migration 009 first.'; end if; end $$;
create table public.jf_notifications (
 id uuid primary key default gen_random_uuid(), shop_id uuid references public.jf_shops(id),
 recipient_id uuid references public.jf_profiles(id), kind text not null,
 title text not null, body text not null default '', reference_id uuid,
 created_at timestamptz not null default now()
);
create index jf_notifications_shop_time on public.jf_notifications(shop_id,created_at desc);
create table public.jf_notification_reads (
 notification_id uuid not null references public.jf_notifications(id),user_id uuid not null references public.jf_profiles(id),read_at timestamptz not null default now(),primary key(notification_id,user_id)
);
create table public.jf_password_requests (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.jf_profiles(id),shop_id uuid not null references public.jf_shops(id),
 status text not null default 'pending' check(status in ('pending','approved','denied','used','expired')),
 requested_at timestamptz not null default now(),decided_at timestamptz,decided_by uuid references public.jf_profiles(id),expires_at timestamptz,mail_requested_at timestamptz
);
create unique index jf_password_pending on public.jf_password_requests(user_id) where status='pending';
alter table public.jf_notifications enable row level security;
alter table public.jf_notification_reads enable row level security;
alter table public.jf_password_requests enable row level security;
revoke all on public.jf_notifications,public.jf_notification_reads,public.jf_password_requests from public,anon,authenticated;

create function jioflow_private.notification_visible(sid uuid,recipient uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select jioflow_private.session_allowed() and
 (recipient=auth.uid() or (recipient is null and (jioflow_private.is_creator() or jioflow_private.manages_shop(sid))));
$$;
create function public.jf_notifications_feed(target_shop uuid default null) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('shop_scope',target_shop,'items',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from
 (select n.*,exists(select 1 from public.jf_notification_reads r where r.notification_id=n.id and r.user_id=auth.uid()) as is_read
 from public.jf_notifications n where (target_shop is null or n.shop_id=target_shop or n.shop_id is null) and jioflow_private.notification_visible(n.shop_id,n.recipient_id) order by n.created_at desc limit 50) x),'[]'::jsonb),
 'unread_count',(select count(*) from public.jf_notifications n where (target_shop is null or n.shop_id=target_shop or n.shop_id is null) and jioflow_private.notification_visible(n.shop_id,n.recipient_id) and not exists(select 1 from public.jf_notification_reads r where r.notification_id=n.id and r.user_id=auth.uid())));
$$;
create function public.jf_notification_read(notification uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.jf_notifications where id=notification and jioflow_private.notification_visible(shop_id,recipient_id)) then raise exception 'Notification access denied.' using errcode='42501'; end if;
 insert into public.jf_notification_reads(notification_id,user_id) values(notification,auth.uid()) on conflict do nothing;
 return true;
end $$;
create function public.jf_request_password_reset() returns uuid
language plpgsql security definer set search_path='' as $$
declare m public.jf_memberships%rowtype; rid uuid;
begin
 if not jioflow_private.session_allowed() then raise exception 'Sign in or contact your administrator.' using errcode='42501'; end if;
 perform 1 from public.jf_profiles where id=auth.uid() for update;
 select * into m from public.jf_memberships where user_id=auth.uid() and role='agent' and status in ('pending','active');
 if not found or not exists(select 1 from public.jf_shops where id=m.shop_id and active) then raise exception 'Agent access required.' using errcode='42501'; end if;
 select id into rid from public.jf_password_requests where user_id=auth.uid() and status='pending';if rid is not null then return rid; end if;
 if exists(select 1 from public.jf_password_requests where user_id=auth.uid() and requested_at>now()-interval '1 minute') then raise exception 'Wait a minute before requesting again.' using errcode='22023'; end if;
 insert into public.jf_password_requests(user_id,shop_id) values(auth.uid(),m.shop_id) returning id into rid;
 insert into public.jf_notifications(shop_id,kind,title,body,reference_id) values(m.shop_id,'password_request','Agent password reset requested',(select full_name||' · '||coalesce(user_code,'') from public.jf_profiles where id=auth.uid()),rid);
 return rid;
end $$;
create function public.jf_decide_password_reset(request_id uuid,approve boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.jf_password_requests%rowtype;
begin
 select * into r from public.jf_password_requests where id=request_id for update;
 if not found or not jioflow_private.manages_shop(r.shop_id) then raise exception 'Approval is not permitted.' using errcode='42501'; end if;
 if r.status<>'pending' then raise exception 'This request has already been handled.' using errcode='22023'; end if;
 if not exists(select 1 from public.jf_memberships m join public.jf_profiles p on p.id=m.user_id where m.user_id=r.user_id and m.shop_id=r.shop_id and m.role='agent' and m.status in ('active','pending') and p.active and p.deleted_at is null) then raise exception 'Agent access changed.' using errcode='42501'; end if;
 update public.jf_password_requests set status=case when approve then 'approved' else 'denied' end,decided_at=now(),decided_by=auth.uid(),expires_at=case when approve then now()+interval '1 hour' end where id=r.id;
 insert into public.jf_notifications(shop_id,recipient_id,kind,title,body,reference_id) values(r.shop_id,r.user_id,'password_decision',case when approve then 'Password reset approved' else 'Password reset declined' end,case when approve then 'Your administrator can send a reset link to your account email. Approval expires in one hour.' else 'Contact your administrator for help.' end,r.id);
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),r.user_id,case when approve then 'approve_password_reset' else 'deny_password_reset' end,jsonb_build_object('request_id',r.id));
 return jsonb_build_object('message',case when approve then 'Reset approved. Send the reset email to the Agent.' else 'Password reset declined.' end);
end $$;
create function public.jf_authorize_agent_reset(request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.jf_password_requests%rowtype; email_address text;
begin
 select * into r from public.jf_password_requests where id=request_id for update;
 if not found or not jioflow_private.manages_shop(r.shop_id) or r.status<>'approved' or r.expires_at<=now() then raise exception 'A current reset approval is required.' using errcode='42501'; end if;
 if r.mail_requested_at>now()-interval '1 minute' then raise exception 'Wait a minute before requesting another email.' using errcode='22023'; end if;
 if not exists(select 1 from public.jf_memberships m join public.jf_profiles p on p.id=m.user_id where m.user_id=r.user_id and m.shop_id=r.shop_id and m.role='agent' and m.status in ('pending','active') and p.active and p.deleted_at is null) then raise exception 'Agent access changed.' using errcode='42501'; end if;
 select email into email_address from auth.users where id=r.user_id;
 update public.jf_password_requests set mail_requested_at=now() where id=r.id;
 return jsonb_build_object('email',email_address,'user_id',r.user_id);
end $$;
create function public.jf_password_requests_feed() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(x) order by x.requested_at desc),'[]'::jsonb) from
 (select r.*,p.full_name,p.user_code,p.email from public.jf_password_requests r join public.jf_profiles p on p.id=r.user_id
 where jioflow_private.manages_shop(r.shop_id) and (r.status='pending' or r.status='approved' and r.expires_at>now()) order by r.requested_at desc limit 100) x;
$$;

create function public.jf_start_agent_reset(target_user uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare m public.jf_memberships%rowtype; rid uuid;
begin
 perform 1 from public.jf_profiles where id=target_user and active and deleted_at is null for update;
 select * into m from public.jf_memberships where user_id=target_user and role='agent' and status in ('pending','active');
 if not found or not jioflow_private.manages_shop(m.shop_id) then raise exception 'Agent management access required.' using errcode='42501'; end if;
 select id into rid from public.jf_password_requests where user_id=target_user and status='pending';if rid is not null then return rid; end if;
 insert into public.jf_password_requests(user_id,shop_id) values(target_user,m.shop_id) returning id into rid;
 insert into public.jf_notifications(shop_id,kind,title,body,reference_id) values(m.shop_id,'password_request','Agent password reset requested',(select full_name||' · '||coalesce(user_code,'') from public.jf_profiles where id=target_user),rid);
 return rid;
end $$;
create function public.jf_password_self_service() returns boolean
language sql stable security definer set search_path='' as $$
 select jioflow_private.session_allowed() and
 not exists(select 1 from public.jf_memberships where user_id=auth.uid() and role='agent' and status<>'removed') and
 (jioflow_private.is_creator() or exists(select 1 from public.jf_shops where owner_id=auth.uid() and active) or exists(select 1 from public.jf_memberships where user_id=auth.uid() and role='admin' and status='active'));
$$;
create function public.jf_is_agent_account(target_user uuid) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501'; end if;
 return exists(select 1 from public.jf_memberships where user_id=target_user and role='agent' and status<>'removed');
end $$;
revoke all on function public.jf_start_agent_reset(uuid),public.jf_password_self_service(),public.jf_is_agent_account(uuid) from public,anon,authenticated;
grant execute on function public.jf_start_agent_reset(uuid),public.jf_password_self_service(),public.jf_is_agent_account(uuid) to authenticated;
create function public.jf_can_reset_password() returns boolean
language sql stable security definer set search_path='' as $$
 select jioflow_private.session_allowed() and
 (not exists(select 1 from public.jf_memberships where user_id=auth.uid() and role='agent' and status<>'removed') or exists(select 1 from public.jf_password_requests r join public.jf_shops s on s.id=r.shop_id where r.user_id=auth.uid() and r.status='approved' and r.expires_at>now() and s.active));
$$;
revoke all on function public.jf_can_reset_password() from public,anon,authenticated;
grant execute on function public.jf_can_reset_password() to authenticated;
-- Enforcement at Auth storage also blocks direct provider calls without approval.
-- Login/token refresh does not modify the stored password hash.
create function jioflow_private.guard_agent_password_change() returns trigger
language plpgsql security definer set search_path='' as $$
declare rid uuid;
begin
 if new.encrypted_password is not distinct from old.encrypted_password then return new; end if;
 if exists(select 1 from public.jf_memberships where user_id=new.id and role='agent' and status<>'removed') then
  select r.id into rid from public.jf_password_requests r join public.jf_profiles p on p.id=r.user_id join public.jf_shops s on s.id=r.shop_id
   where r.user_id=new.id and r.status='approved' and r.expires_at>now() and p.active and p.deleted_at is null and s.active
   and exists(select 1 from public.jf_memberships m where m.user_id=new.id and m.shop_id=r.shop_id and m.role='agent' and m.status in ('pending','active'))
   order by r.decided_at desc limit 1 for update of r;
  if rid is null then raise exception 'Agent password reset requires administrator approval.' using errcode='42501'; end if;
  update public.jf_password_requests set status='used' where id=rid;
 end if;
 return new;
end $$;
revoke all on function jioflow_private.guard_agent_password_change() from public,anon,authenticated;
create trigger jf_agent_password_approval before update of encrypted_password on auth.users for each row execute function jioflow_private.guard_agent_password_change();

create function jioflow_private.emit_login_notification() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.jf_notifications(shop_id,kind,title,body,reference_id) values(new.shop_id,'agent_login','Agent login approval requested',(select full_name||' · '||coalesce(user_code,'') from public.jf_profiles where id=new.user_id),new.session_id);
 return new;
end $$;
create trigger jf_agent_login_notification after insert on public.jf_agent_sessions for each row execute function jioflow_private.emit_login_notification();
insert into public.jf_notifications(shop_id,kind,title,body,reference_id) select a.shop_id,'agent_login','Agent login approval requested',p.full_name||' · '||coalesce(p.user_code,''),a.session_id from public.jf_agent_sessions a join public.jf_profiles p on p.id=a.user_id where a.status='pending';
create function jioflow_private.emit_order_notification() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' or new.status is distinct from old.status then
  insert into public.jf_notifications(shop_id,kind,title,body,reference_id) values(new.shop_id,'order',case when tg_op='INSERT' then 'New order' else 'Order status updated' end,new.order_number||' · '||new.status,new.id);
  if new.entered_by is not null and exists(select 1 from public.jf_memberships where user_id=new.entered_by and shop_id=new.shop_id and role='agent' and status<>'removed') then insert into public.jf_notifications(shop_id,recipient_id,kind,title,body,reference_id) values(new.shop_id,new.entered_by,'order','Your order update',new.order_number||' · '||new.status,new.id);end if;
 end if;
 return new;
end $$;
create trigger jf_order_notification after insert or update of status on public.jf_orders for each row execute function jioflow_private.emit_order_notification();
revoke all on function jioflow_private.emit_login_notification(),jioflow_private.emit_order_notification(),jioflow_private.notification_visible(uuid,uuid) from public,anon,authenticated;
revoke all on function public.jf_notifications_feed(uuid),public.jf_notification_read(uuid),public.jf_request_password_reset(),public.jf_decide_password_reset(uuid,boolean),public.jf_authorize_agent_reset(uuid),public.jf_password_requests_feed() from public,anon,authenticated;
grant execute on function public.jf_notifications_feed(uuid),public.jf_notification_read(uuid),public.jf_request_password_reset(),public.jf_decide_password_reset(uuid,boolean),public.jf_authorize_agent_reset(uuid),public.jf_password_requests_feed() to authenticated;
alter table public.jf_shops add column business_type text not null default '',add column district text not null default '',add column facebook_url text not null default '';
create function public.jf_save_business(target_shop uuid default null,details jsonb default '{}') returns uuid
language plpgsql security definer set search_path='' as $$
declare sid uuid:=target_shop;
begin
 if not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501'; end if;
 if jsonb_typeof(details) is distinct from 'object' or exists(select 1 from jsonb_object_keys(details) k where k not in ('name','email','phone','address','website','logo_path','business_type','district','facebook_url')) then raise exception 'Check the business details.' using errcode='22023'; end if;
 if length(trim(coalesce(details->>'name',''))) not between 1 and 120 or coalesce(details->>'email','') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or length(details->>'email')>254 or length(trim(coalesce(details->>'phone',''))) not between 6 and 30 or length(trim(coalesce(details->>'address',''))) not between 1 and 1000 or length(coalesce(details->>'business_type',''))>80 or length(coalesce(details->>'district',''))>100 or length(coalesce(details->>'facebook_url',''))>500 or (coalesce(details->>'facebook_url','')<>'' and details->>'facebook_url' !~ '^https?://[^[:space:]]+$') or (coalesce(details->>'website','')<>'' and details->>'website' !~ '^https?://[^[:space:]]+$') then raise exception 'Enter a business name, valid email, phone and address. Check website links.' using errcode='22023'; end if;
 if sid is null then sid:=public.jf_create_shop(details->>'name',details->>'email',details->>'phone',details->>'address',coalesce(details->>'website',''));end if;
 perform public.jf_manage_shop(sid,'edit',details-'business_type'-'district'-'facebook_url');
 update public.jf_shops set business_type=coalesce(details->>'business_type',''),district=coalesce(details->>'district',''),facebook_url=coalesce(details->>'facebook_url','') where id=sid;
 return sid;
end $$;
revoke all on function public.jf_save_business(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.jf_save_business(uuid,jsonb) to authenticated;
create function jioflow_private.emit_shop_notification() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.jf_notifications(shop_id,kind,title,body,reference_id) values(new.id,'shop','Business created',new.name,new.id);return new;
end $$;
revoke all on function jioflow_private.emit_shop_notification() from public,anon,authenticated;
create trigger jf_shop_notification after insert on public.jf_shops for each row execute function jioflow_private.emit_shop_notification();

insert into public.jf_schema_versions(version) values('010_notifications_passwords');
commit;
