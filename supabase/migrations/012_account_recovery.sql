-- Apply once after 011. Creator-only account diagnostics and orphan/unassigned recovery.
begin;
do $$ begin if not exists(select 1 from public.jf_schema_versions where version='011_shop_pause_delete') then raise exception 'Apply migration 011 first.';end if;end $$;
create function public.jf_lookup_account(account_email text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u auth.users%rowtype;p public.jf_profiles%rowtype;sid uuid;assigned_role text;
begin
 if not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501';end if;
 if length(trim(coalesce(account_email,'')))>254 or trim(coalesce(account_email,'')) !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Enter a valid email.' using errcode='22023';end if;
 select * into u from auth.users where lower(email)=lower(trim(account_email));
 if not found then return jsonb_build_object('exists',false);end if;
 select * into p from public.jf_profiles where id=u.id;
 select id,'owner' into sid,assigned_role from public.jf_shops where owner_id=u.id limit 1;
 if sid is null then select shop_id,role into sid,assigned_role from public.jf_memberships where user_id=u.id and status<>'removed' limit 1;end if;
 return jsonb_build_object('exists',true,'id',u.id,'email',u.email,'name',coalesce(p.full_name,''),'profile_exists',p.id is not null,'active',coalesce(p.active,false),'removed',p.deleted_at is not null,'verified',u.email_confirmed_at is not null,'managed_agent',coalesce(p.managed_agent,false),'protected',p.platform_role='creator','shop_id',sid,'shop_name',(select name from public.jf_shops where id=sid),'role',assigned_role,
 'state',case when p.platform_role='creator' then 'protected' when p.id is null then 'profile_missing' when p.deleted_at is not null then 'removed' when sid is null then 'unassigned' when not p.active then 'inactive' when u.email_confirmed_at is null then 'email_pending' else 'assigned' end);
end $$;
create function public.jf_recover_account(account_email text,target_shop uuid,desired_role text,person_name text,confirm_restore boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u auth.users%rowtype;p public.jf_profiles%rowtype;permissions jsonb;
begin
 if not jioflow_private.is_creator() then raise exception 'Creator access required.' using errcode='42501';end if;
 if confirm_restore is not true then raise exception 'Confirm reactivating and assigning this account.' using errcode='22023';end if;
 if desired_role not in ('owner','admin','agent') or desired_role is null or length(trim(coalesce(person_name,''))) not between 1 and 120 then raise exception 'Choose a role and enter the name.' using errcode='22023';end if;
 -- The database resolves the identity by email. Browser-supplied account IDs are not trusted.
 select * into u from auth.users where lower(email)=lower(trim(account_email)) for update;
 if not found then raise exception 'No existing login identity was found. Use Add Account.' using errcode='P0002';end if;
 select * into p from public.jf_profiles where id=u.id for update;
 if u.id=auth.uid() or p.platform_role='creator' then raise exception 'The Creator account cannot be recovered here.' using errcode='42501';end if;
 if exists(select 1 from public.jf_shops where owner_id=u.id) or exists(select 1 from public.jf_memberships where user_id=u.id and status<>'removed') then raise exception 'This account already has a business. Edit or Activate it in Account Access.' using errcode='22023';end if;
 if not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null) then raise exception 'Select an active business.' using errcode='22023';end if;
 if desired_role in ('owner','admin') and (p.managed_agent or (p.id is null and to_jsonb(u)->'raw_app_meta_data'->>'jioflow_managed_agent'='true')) then raise exception 'A managed Agent requires a verified contact email before promotion.' using errcode='42501';end if;
 if p.id is null and to_jsonb(u)->'raw_app_meta_data'->>'jioflow_managed_agent'='true' then raise exception 'This managed Agent identity needs its original Jio ID/profile setup before recovery.' using errcode='42501';end if;
 if p.id is null then
  insert into public.jf_profiles(id,full_name,email,email_verified_at) values(u.id,trim(person_name),u.email,u.email_confirmed_at);
 else
  update public.jf_profiles set full_name=trim(person_name),active=true,deleted_at=null where id=u.id;
 end if;
 permissions:=case when desired_role='admin' then '{"users":true,"assign":true,"booking":true,"import":true,"settings":true}'::jsonb when desired_role='agent' then '{"assign":true,"price":true,"discount":true,"advance":true,"booking":true}'::jsonb else '{}'::jsonb end;
 perform public.jf_save_profile(u.id,jsonb_build_object('shop_id',target_shop,'role',desired_role,'permissions',permissions));
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),u.id,'recover_account',jsonb_build_object('shop_id',target_shop,'role',desired_role,'had_profile',p.id is not null));
 insert into public.jf_notifications(shop_id,kind,title,body,reference_id) values(target_shop,'account','Account restored',trim(person_name),u.id);
 return jsonb_build_object('user_id',u.id,'verified',u.email_confirmed_at is not null,'message',case when u.email_confirmed_at is not null then 'Account restored and assigned. Sign in with its existing password. The password was not changed.' else 'Account restored and assigned. Email verification is still required before Owner/Admin login.' end);
end $$;
revoke all on function public.jf_lookup_account(text),public.jf_recover_account(text,uuid,text,text,boolean) from public,anon,authenticated;
grant execute on function public.jf_lookup_account(text),public.jf_recover_account(text,uuid,text,text,boolean) to authenticated;
insert into public.jf_schema_versions(version) values('012_account_recovery');
commit;
