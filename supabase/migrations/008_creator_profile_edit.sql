-- Run once after 007. Creator-controlled profile, role and business editing.
begin;
do $$ begin if not exists(select 1 from public.jf_schema_versions where version='007_live_orders') then raise exception 'Apply migration 007 first.'; end if;end $$;
alter table public.jf_profiles add column job_title text not null default '',add column address text not null default '',add column user_code text not null default '',add column pending_email text not null default '';
alter table public.jf_memberships drop constraint jf_memberships_user_id_key;
create unique index jf_one_current_membership on public.jf_memberships(user_id) where status<>'removed';
create or replace function jioflow_private.sync_verified_email() returns trigger language plpgsql security definer set search_path='' as $$begin update public.jf_profiles set email=new.email,email_verified_at=new.email_confirmed_at,pending_email=coalesce(new.email_change,'') where id=new.id;return new;end $$;
drop trigger jf_sync_verified_email on auth.users;
create trigger jf_sync_verified_email after update of email,email_change,email_confirmed_at on auth.users for each row execute function jioflow_private.sync_verified_email();
create function public.jf_save_profile(target_user uuid,details jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare target public.jf_profiles%rowtype; sid uuid; desired_role text; old_member public.jf_memberships%rowtype; permitted jsonb; new_member uuid; is_me boolean:=target_user=auth.uid(); k text; v jsonb; avatar text;
begin
 if not jioflow_private.session_allowed() then raise exception 'Please sign in again.' using errcode='42501';end if;
 if not is_me and not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501';end if;
 select * into target from public.jf_profiles where id=target_user for update;
 if not found or target.deleted_at is not null or (not is_me and target.platform_role='creator') then raise exception 'This account cannot be edited.' using errcode='42501';end if;
 if jsonb_typeof(details) is distinct from 'object' or exists(select 1 from jsonb_object_keys(details) key where key not in ('full_name','phone','job_title','address','user_code','avatar_path','shop_id','role','permissions')) then raise exception 'Unsupported profile field.';end if;
 if is_me and (details?'role' or details?'shop_id' or details?'permissions') then raise exception 'You cannot change your own account access here.' using errcode='42501';end if;
 if length(trim(coalesce(details->>'full_name',target.full_name))) not between 1 and 120 or length(coalesce(details->>'phone',target.phone))>30 or length(coalesce(details->>'job_title',target.job_title))>100 or length(coalesce(details->>'address',target.address))>1000 or length(coalesce(details->>'user_code',target.user_code))>50 then raise exception 'Check name, phone, title, address and user code.';end if;
 avatar:=coalesce(details->>'avatar_path',target.avatar_path);
 if details?'avatar_path' and coalesce(avatar,'')<>'' and (length(avatar)>350000 or avatar !~ '^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$') then raise exception 'Upload a PNG, JPEG or WebP image under 250 KB.';end if;
 if details?'role' or details?'shop_id' or details?'permissions' then
  if is_me or not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501';end if;
  select * into old_member from public.jf_memberships where user_id=target_user and status<>'removed' for update;
  desired_role:=coalesce(details->>'role',case when exists(select 1 from public.jf_shops where owner_id=target_user) then 'owner' else old_member.role end);
  sid:=coalesce(nullif(details->>'shop_id','')::uuid,(select id from public.jf_shops where owner_id=target_user),old_member.shop_id);
  if desired_role not in ('owner','admin','agent') or desired_role is null or sid is null then raise exception 'Select a role and business.';end if;
  -- Lock every old/new shop in stable order. A business can have one Owner.
  perform 1 from public.jf_shops where id=sid or owner_id=target_user or id=old_member.shop_id order by id for update;
  if not exists(select 1 from public.jf_shops where id=sid and active) then raise exception 'Select an active business.';end if;
  if desired_role='owner' and exists(select 1 from public.jf_shops where id=sid and owner_id is not null and owner_id<>target_user) then raise exception 'This business already has an Owner.' using errcode='23505';end if;
  permitted:=coalesce(details->'permissions',old_member.permissions,'{}'::jsonb);
  if jsonb_typeof(permitted) is distinct from 'object' then raise exception 'Permissions must be an object.';end if;
  for k,v in select * from jsonb_each(permitted) loop
   if k not in ('users','assign','booking','products','import','export','profit','settings','approval','logout','integration','pull','price','discount','advance') or jsonb_typeof(v)<>'boolean' then raise exception 'Unsupported permission.';end if;
   if desired_role='agent' and k in ('users','products','export','profit','settings','approval','logout','integration') and v='true'::jsonb then raise exception 'Agents cannot receive administrative or profit access.';end if;
  end loop;
  if old_member.id is not null and (old_member.shop_id<>sid or old_member.role<>desired_role) then
   update public.jf_customers set assigned_membership_id=null,permanent=false where assigned_membership_id=old_member.id;
   delete from public.jf_group_members where membership_id=old_member.id;
  end if;
  if old_member.id is not null and (old_member.shop_id<>sid or desired_role='owner') then update public.jf_memberships set status='removed' where id=old_member.id;end if;
  update public.jf_shops set owner_id=null where owner_id=target_user and (id<>sid or desired_role<>'owner');
  if desired_role='owner' then update public.jf_shops set owner_id=target_user where id=sid;
  else
   insert into public.jf_memberships(shop_id,user_id,role,status,permissions) values(sid,target_user,desired_role,case when desired_role='agent' then 'pending' else 'active' end,permitted)
   on conflict(shop_id,user_id) do update set role=excluded.role,permissions=excluded.permissions,status=case when public.jf_memberships.role=excluded.role and public.jf_memberships.status<>'removed' then public.jf_memberships.status else excluded.status end returning id into new_member;
  end if;
  insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by) select id,target_user,auth.uid() from auth.sessions where user_id=target_user on conflict do nothing;
 end if;
 update public.jf_profiles set full_name=trim(coalesce(details->>'full_name',full_name)),phone=trim(coalesce(details->>'phone',phone)),job_title=trim(coalesce(details->>'job_title',job_title)),address=coalesce(details->>'address',address),user_code=trim(coalesce(details->>'user_code',user_code)),avatar_path=nullif(avatar,'') where id=target_user;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),target_user,'profile_edit',jsonb_build_object('fields',array(select jsonb_object_keys(details)),'shop_id',sid,'role',desired_role));
 return jsonb_build_object('message','Profile saved. Access changes require a fresh login.');
end $$;
create function public.jf_account_email_target(target_user uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.jf_profiles%rowtype;
begin
 if not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501';end if;
 select * into p from public.jf_profiles where id=target_user;
 if not found or p.deleted_at is not null or p.platform_role='creator' or target_user=auth.uid() then raise exception 'This account cannot be managed.' using errcode='42501';end if;
 if (select count(*) from jioflow_private.account_audit where actor_id=auth.uid() and action='email_action' and created_at>now()-interval '1 minute')>=5 then raise exception 'Wait one minute before requesting more emails.';end if;
 insert into jioflow_private.account_audit(actor_id,target_id,action) values(auth.uid(),target_user,'email_action');
 return (select jsonb_build_object('email',u.email,'pending_email',coalesce(u.email_change,''),'verified',u.email_confirmed_at is not null) from auth.users u where u.id=p.id);
end $$;
revoke all on function public.jf_save_profile(uuid,jsonb),public.jf_account_email_target(uuid) from public,anon,authenticated;
grant execute on function public.jf_save_profile(uuid,jsonb),public.jf_account_email_target(uuid) to authenticated;
insert into public.jf_schema_versions(version) values('008_creator_profile_edit');commit;
