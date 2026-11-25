begin;
CREATE OR REPLACE FUNCTION jioflow_private.sync_verified_email() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 UPDATE public.jf_profiles SET email=NEW.email,pending_email=COALESCE(NEW.email_change,''),email_verified_at=CASE WHEN managed_agent AND NEW.email IS NOT DISTINCT FROM OLD.email THEN NULL ELSE NEW.email_confirmed_at END,managed_agent=CASE WHEN managed_agent AND NEW.email IS DISTINCT FROM OLD.email AND NEW.email_confirmed_at IS NOT NULL THEN FALSE ELSE managed_agent END WHERE id=NEW.id;
 RETURN NEW;
END;$$;
create or replace function public.jf_agent_workspace_context(target_shop uuid,target_agent uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare m public.jf_memberships%rowtype;p public.jf_profiles%rowtype;authorized boolean;
begin
 select * into m from public.jf_memberships where id=target_agent and shop_id=target_shop and role in('owner','admin','agent') and status='active';
 if not found or not jioflow_private.session_allowed() then raise exception 'Workspace access denied.' using errcode='42501';end if;
 authorized:=jioflow_private.is_creator() or (m.user_id<>auth.uid() and jioflow_private.has_permission(target_shop,'users') and (jioflow_private.owns_shop(target_shop) and m.role in('admin','agent') or m.role='agent' and exists(select 1 from public.jf_memberships a where a.shop_id=target_shop and a.user_id=auth.uid() and a.role='admin' and a.status='active')));
 if not coalesce(authorized,false) then raise exception 'Workspace access denied.' using errcode='42501';end if;
 select * into p from public.jf_profiles where id=m.user_id and active and deleted_at is null and platform_role is distinct from 'creator';
 if not found then raise exception 'Account is inactive.' using errcode='42501';end if;
 if not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null and paused_at is null) then raise exception 'Business is unavailable.' using errcode='42501';end if;
 return jsonb_build_object('member',to_jsonb(m),'profile',to_jsonb(p),'can_edit_layout',jioflow_private.has_permission(target_shop,'settings'));
end$$;
revoke all on function public.jf_agent_workspace_context(uuid,uuid) from public,anon;
grant execute on function public.jf_agent_workspace_context(uuid,uuid) to authenticated;
insert into public.jf_schema_versions(version) values('045_supervisor_workspaces') on conflict do nothing;
commit;
