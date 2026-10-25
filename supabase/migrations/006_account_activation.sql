-- Run once after migration 005. Does not change ownership, assignments or history.
begin;
do $$ begin if not exists(select 1 from public.jf_schema_versions where version='005_account_management') then raise exception 'Apply migration 005 first.'; end if; end $$;
create or replace function public.jf_manage_account(target_user uuid,account_action text,details jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare target public.jf_profiles%rowtype; session_count integer:=0; person_name text; person_phone text;
begin
 if not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501'; end if;
 if target_user=auth.uid() then raise exception 'You cannot manage your own Creator account here.' using errcode='42501'; end if;
 select * into target from public.jf_profiles where id=target_user for update;
 if not found or target.deleted_at is not null or target.platform_role='creator' then raise exception 'This account cannot be managed.' using errcode='42501'; end if;
 if account_action not in ('edit','force_logout','remove','activate','deactivate') then raise exception 'Unsupported account action.' using errcode='22023'; end if;
 if account_action='edit' then
  if jsonb_typeof(details) is distinct from 'object' or exists(select 1 from jsonb_object_keys(details) k where k not in ('full_name','phone')) then raise exception 'Only name and phone can be edited here.' using errcode='22023'; end if;
  person_name:=trim(coalesce(details->>'full_name',target.full_name));person_phone:=trim(coalesce(details->>'phone',target.phone));
  if length(person_name) not between 1 and 120 or length(person_phone)>30 then raise exception 'Enter a valid name and phone.' using errcode='22023'; end if;
  update public.jf_profiles set full_name=person_name,phone=person_phone where id=target_user;
  insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),target_user,'edit',jsonb_build_object('before_name',target.full_name,'after_name',person_name,'before_phone',target.phone,'after_phone',person_phone));
  return jsonb_build_object('message','Account details saved.');
 end if;
 if account_action='activate' then
  update public.jf_profiles set active=true where id=target_user;
  insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),target_user,'activate',jsonb_build_object('previous_active',target.active));
  return jsonb_build_object('message','Account activated. Sign in again to continue.');
 end if;
 insert into jioflow_private.revoked_sessions(session_id,user_id,revoked_by)
  select s.id,target_user,auth.uid() from auth.sessions s where s.user_id=target_user
  on conflict(session_id) do nothing;
 get diagnostics session_count=row_count;
 if account_action='deactivate' then
  update public.jf_profiles set active=false where id=target_user;
  insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),target_user,'deactivate',jsonb_build_object('previous_active',target.active,'revoked_sessions',session_count));
  return jsonb_build_object('revoked_sessions',session_count,'message','Account deactivated. Existing sessions blocked; assignments and history preserved.');
 end if;
 if account_action='remove' then
  -- Clear permanent ownership and assignments together, preserving all history.
  update public.jf_customers set assigned_membership_id=null,permanent=false
   where assigned_membership_id in(select id from public.jf_memberships where user_id=target_user);
  delete from public.jf_group_members where membership_id in(select id from public.jf_memberships where user_id=target_user);
  update public.jf_memberships set status='removed' where user_id=target_user;
  update public.jf_shops set owner_id=null where owner_id=target_user;
  update public.jf_profiles set active=false,deleted_at=now() where id=target_user;
 end if;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),target_user,account_action,jsonb_build_object('revoked_sessions',session_count));
 return jsonb_build_object('revoked_sessions',session_count,'message',case when account_action='remove' then 'Account removed. Login disabled; customer and order history preserved.' else 'Existing JioFlow sessions revoked. The user can sign in again.' end);
end $$;
insert into public.jf_schema_versions(version) values('006_account_activation');
commit;
