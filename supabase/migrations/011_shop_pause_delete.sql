-- Apply once after 010. Creator-only workspace pause/resume and permanent shop deletion.
begin;
do $$ begin if not exists(select 1 from public.jf_schema_versions where version='010_notifications_passwords') then raise exception 'Apply migration 010 first.';end if;end $$;
alter table public.jf_shops add column paused_at timestamptz,add column pause_reason text not null default '';
create function public.jf_workspace_status() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare s public.jf_shops%rowtype;
begin
 if not jioflow_private.session_allowed() then raise exception 'Sign in again.' using errcode='42501';end if;
 if jioflow_private.is_creator() then return jsonb_build_object('blocked',false);end if;
 select * into s from public.jf_shops where owner_id=auth.uid() or id in(select shop_id from public.jf_memberships where user_id=auth.uid() and status<>'removed') limit 1;
 if not found then return jsonb_build_object('blocked',false);end if;
 return jsonb_build_object('blocked',not s.active,'paused',s.paused_at is not null,'shop_id',s.id,'name',s.name,'reason',case when s.paused_at is not null then s.pause_reason else '' end);
end $$;
create function public.jf_set_shop_paused(target_shop uuid,is_paused boolean,reason text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.jf_shops%rowtype;
begin
 if not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501';end if;
 if is_paused is null or length(coalesce(reason,''))>500 then raise exception 'Check the pause details.' using errcode='22023';end if;
 select * into s from public.jf_shops where id=target_shop for update;
 if not found or s.archived_at is not null then raise exception 'Select an available shop.' using errcode='22023';end if;
 update public.jf_shops set active=not is_paused,paused_at=case when is_paused then now() end,pause_reason=case when is_paused then trim(coalesce(reason,'')) else '' end where id=target_shop;
 if is_paused then
  insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by)
   select x.id,x.user_id,auth.uid() from auth.sessions x where x.user_id<>auth.uid() and (x.user_id=s.owner_id or exists(select 1 from public.jf_memberships where shop_id=target_shop and user_id=x.user_id and status<>'removed')) on conflict do nothing;
 end if;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),auth.uid(),case when is_paused then 'pause_shop' else 'resume_shop' end,jsonb_build_object('shop_id',target_shop,'reason',left(coalesce(reason,''),500)));
 insert into public.jf_notifications(shop_id,kind,title,body,reference_id) values(target_shop,'shop',case when is_paused then 'Shop paused' else 'Shop resumed' end,s.name,target_shop);
 return jsonb_build_object('message',case when is_paused then 'Shop paused. Owner, Admin and Agent access is blocked.' else 'Shop resumed. Users can sign in again.' end);
end $$;
create function public.jf_delete_shop(target_shop uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.jf_shops%rowtype;t text;
begin
 if not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501';end if;
 select * into s from public.jf_shops where id=target_shop for update;
 if not found then raise exception 'Shop not found.' using errcode='P0002';end if;
 update public.jf_shops set active=false where id=target_shop;
 insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by)
  select x.id,x.user_id,auth.uid() from auth.sessions x where x.user_id<>auth.uid() and (x.user_id=s.owner_id or exists(select 1 from public.jf_memberships where shop_id=target_shop and user_id=x.user_id and status<>'removed')) on conflict do nothing;
 -- Accounts and the audit trail remain. Their deleted-business access is removed.
 update public.jf_profiles p set active=false where p.platform_role is distinct from 'creator' and (p.id=s.owner_id or exists(select 1 from public.jf_memberships where shop_id=target_shop and user_id=p.id and status<>'removed'));
 delete from public.jf_notification_reads where notification_id in(select id from public.jf_notifications where shop_id=target_shop);
 delete from public.jf_notifications where shop_id=target_shop;
 -- Child-first deletion preserves foreign key safety; any failure rolls back the whole action.
 foreach t in array array['jf_courier_events','jf_shipments','jf_order_finance','jf_order_events','jf_payments','jf_notes','jf_order_items'] loop
  execute format('delete from public.%I where shop_id=$1',t) using target_shop;
 end loop;
 update public.jf_orders set original_order_id=null where shop_id=target_shop;
 foreach t in array array['jf_orders','jf_followup_events','jf_followups','jf_customers','jf_product_costs','jf_products','jf_group_members','jf_groups','jf_agent_sessions','jf_password_requests','jf_account_requests','jf_import_jobs','jf_memberships'] loop
  execute format('delete from public.%I where shop_id=$1',t) using target_shop;
 end loop;
 delete from public.jf_shops where id=target_shop;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),auth.uid(),'delete_shop',jsonb_build_object('shop_id',target_shop,'name',s.name));
 insert into public.jf_notifications(recipient_id,kind,title,body,reference_id) values(auth.uid(),'shop','Shop deleted',s.name,target_shop);
 return jsonb_build_object('message','Shop and its business records permanently deleted. User accounts remain inactive.');
end $$;
revoke all on function public.jf_workspace_status(),public.jf_set_shop_paused(uuid,boolean,text),public.jf_delete_shop(uuid) from public,anon,authenticated;
grant execute on function public.jf_workspace_status(),public.jf_set_shop_paused(uuid,boolean,text),public.jf_delete_shop(uuid) to authenticated;
insert into public.jf_schema_versions(version) values('011_shop_pause_delete');
commit;
