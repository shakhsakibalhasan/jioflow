begin;
create or replace function jioflow_private.can_review_login(target_shop uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select jioflow_private.session_allowed() and (jioflow_private.is_creator() or jioflow_private.owns_shop(target_shop) or jioflow_private.has_permission(target_shop,'approval'));
$$;
revoke all on function jioflow_private.can_review_login(uuid) from public,anon;
grant execute on function jioflow_private.can_review_login(uuid) to authenticated;
-- Approval access follows the approval permission rather than user-management access.
drop policy if exists jf_delegated_agent_approval_read on public.jf_agent_sessions;
drop policy if exists jf_agent_sessions_read on public.jf_agent_sessions;
create policy jf_agent_sessions_read on public.jf_agent_sessions for select to authenticated
using(user_id<>auth.uid() and jioflow_private.can_review_login(shop_id));
drop trigger if exists jf_agent_login_notification on public.jf_agent_sessions;
create trigger jf_agent_login_notification after insert on public.jf_agent_sessions for each row execute function jioflow_private.emit_login_notification();
insert into public.jf_schema_versions(version) values('050_login_notification_queue') on conflict do nothing;
commit;
