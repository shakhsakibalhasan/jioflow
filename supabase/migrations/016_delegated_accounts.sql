-- Same-business delegation: Owner manages Admin/Agent; permitted Admin manages Agent only.
begin;
create function jioflow_private.can_manage_lower(target_user uuid,permission_name text default 'users') returns boolean
language sql stable security definer set search_path='' as $$
 select target_user<>auth.uid() and exists(select 1 from public.jf_profiles p join public.jf_memberships m on m.user_id=p.id where p.id=target_user and p.platform_role is distinct from 'creator' and p.deleted_at is null and m.status<>'removed' and not exists(select 1 from public.jf_shops s where s.owner_id=p.id) and jioflow_private.has_permission(m.shop_id,permission_name) and (jioflow_private.owns_shop(m.shop_id) and m.role in ('admin','agent') or m.role='agent' and exists(select 1 from public.jf_memberships a where a.shop_id=m.shop_id and a.user_id=auth.uid() and a.role='admin' and a.status='active')));
$$;
revoke all on function jioflow_private.can_manage_lower(uuid,text) from public,anon,authenticated;
alter function public.jf_save_profile(uuid,jsonb) rename to jf_save_profile_creator;
revoke all on function public.jf_save_profile_creator(uuid,jsonb) from public,anon,authenticated;
create function public.jf_save_profile(target_user uuid,details jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.jf_profiles%rowtype;m public.jf_memberships%rowtype;k text;v jsonb;avatar text;
begin
 if target_user=auth.uid() or jioflow_private.is_creator() then return public.jf_save_profile_creator(target_user,details);end if;
 if not jioflow_private.can_manage_lower(target_user) then raise exception 'This account is outside your management permissions.' using errcode='42501';end if;
 select * into p from public.jf_profiles where id=target_user for update;
 select * into m from public.jf_memberships where user_id=target_user and status<>'removed' for update;
 if jsonb_typeof(details)<>'object' or exists(select 1 from jsonb_object_keys(details) field(key) where field.key not in ('full_name','phone','job_title','address','user_code','avatar_path','permissions')) then raise exception 'Role and business changes require Creator access.' using errcode='42501';end if;
 if length(trim(coalesce(details->>'full_name',p.full_name))) not between 1 and 120 or length(coalesce(details->>'phone',p.phone))>30 or length(coalesce(details->>'address',p.address))>1000 or length(coalesce(details->>'job_title',p.job_title))>120 or length(coalesce(details->>'user_code',p.user_code))>40 then raise exception 'Check profile field lengths.';end if;
 avatar:=coalesce(details->>'avatar_path',p.avatar_path,'');if length(avatar)>350000 or (avatar<>'' and avatar !~ '^data:image/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$') then raise exception 'Upload a valid small profile image.';end if;
 if details?'permissions' then
  if jsonb_typeof(details->'permissions')<>'object' then raise exception 'Invalid permissions.';end if;
  for k,v in select * from jsonb_each(details->'permissions') loop
   if k not in ('users','assign','booking','products','import','export','profit','settings','approval','logout','integration','pull','price','discount','advance') or jsonb_typeof(v)<>'boolean' or (m.role='agent' and k in ('users','products','export','profit','settings','approval','logout','integration') and v='true'::jsonb) then raise exception 'Invalid permission.' using errcode='42501';end if;
  end loop;
  update public.jf_memberships set permissions=details->'permissions' where id=m.id;
 end if;
 update public.jf_profiles set full_name=trim(coalesce(details->>'full_name',full_name)),phone=trim(coalesce(details->>'phone',phone)),job_title=trim(coalesce(details->>'job_title',job_title)),address=coalesce(details->>'address',address),user_code=trim(coalesce(details->>'user_code',user_code)),avatar_path=nullif(avatar,'') where id=target_user;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),target_user,'delegated_profile_edit',jsonb_build_object('shop_id',m.shop_id));
 return jsonb_build_object('message','Profile saved.');
end $$;
alter function public.jf_manage_account(uuid,text,jsonb) rename to jf_manage_account_creator;
revoke all on function public.jf_manage_account_creator(uuid,text,jsonb) from public,anon,authenticated;
create function public.jf_manage_account(target_user uuid,account_action text,details jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare m public.jf_memberships%rowtype;
begin
 if jioflow_private.is_creator() then return public.jf_manage_account_creator(target_user,account_action,details);end if;
 if not jioflow_private.can_manage_lower(target_user,case when account_action='force_logout' then 'logout' else 'users' end) then raise exception 'This account cannot be managed.' using errcode='42501';end if;
 if account_action not in ('activate','deactivate','force_logout','remove') then raise exception 'Unsupported action.';end if;
 select * into m from public.jf_memberships where user_id=target_user and status<>'removed' for update;
 if account_action in ('deactivate','remove','force_logout') then
  insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by) select id,target_user,auth.uid() from auth.sessions where user_id=target_user on conflict do nothing;
  update public.jf_agent_sessions set status='revoked' where user_id=target_user and status in ('pending','approved');
 end if;
 if account_action in ('activate','deactivate') then update public.jf_profiles set active=account_action='activate' where id=target_user;end if;
 if account_action='remove' then
  update public.jf_customers set assigned_membership_id=null,permanent=false where shop_id=m.shop_id and assigned_membership_id=m.id;
  delete from public.jf_group_members where shop_id=m.shop_id and membership_id=m.id;
  update public.jf_memberships set status='removed' where id=m.id;update public.jf_profiles set active=false,deleted_at=now() where id=target_user;
 end if;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),target_user,'delegated_'||account_action,jsonb_build_object('shop_id',m.shop_id));
 return jsonb_build_object('message','Account updated.');
end $$;
-- Recovery stays email-based, and existing Agent reset approval checks remain in force.
alter function public.jf_account_email_target(uuid) rename to jf_account_email_target_creator;
revoke all on function public.jf_account_email_target_creator(uuid) from public,anon,authenticated;
create function public.jf_account_email_target(target_user uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if jioflow_private.is_creator() then return public.jf_account_email_target_creator(target_user);end if;
 if not jioflow_private.can_manage_lower(target_user) then raise exception 'Account email access denied.' using errcode='42501';end if;
 if (select count(*) from jioflow_private.account_audit where actor_id=auth.uid() and action='email_action' and created_at>now()-interval '1 minute')>=5 then raise exception 'Wait one minute.';end if;
 insert into jioflow_private.account_audit(actor_id,target_id,action) values(auth.uid(),target_user,'email_action');
 return(select jsonb_build_object('email',email,'pending_email',coalesce(email_change,''),'verified',email_confirmed_at is not null) from auth.users where id=target_user);
end $$;
revoke all on function public.jf_save_profile(uuid,jsonb),public.jf_manage_account(uuid,text,jsonb),public.jf_account_email_target(uuid) from public,anon,authenticated;
grant execute on function public.jf_save_profile(uuid,jsonb),public.jf_manage_account(uuid,text,jsonb),public.jf_account_email_target(uuid) to authenticated;
insert into public.jf_schema_versions(version) values('016_delegated_accounts');commit;
