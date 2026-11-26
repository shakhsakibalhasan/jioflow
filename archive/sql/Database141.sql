begin;
alter table public.jf_agent_sessions add column if not exists device_details141 jsonb not null default '{}'::jsonb;
create or replace function public.jf_agent_device141(details jsonb) returns boolean language plpgsql security definer set search_path='' as $$
declare sid uuid;begin
 sid:=nullif(auth.jwt()->>'session_id','')::uuid;
 if auth.uid() is null or sid is null or jsonb_typeof(details)<>'object' then return false;end if;
 update public.jf_agent_sessions a set device_details141=jsonb_build_object('user_agent',left(coalesce(details->>'user_agent',''),500),'device_type',case when details->>'device_type'='Mobile / tablet' then 'Mobile / tablet' else 'Desktop' end)
 where a.session_id=sid and a.user_id=auth.uid() and a.status in('pending','approved') and exists(select 1 from public.jf_memberships m where m.shop_id=a.shop_id and m.user_id=a.user_id and m.role='agent' and m.status='active');
 return found;
end$$;
create or replace function public.jf_login_details141(target_session uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.jf_agent_sessions%rowtype;p public.jf_profiles%rowtype;old_session jsonb;begin
 select * into a from public.jf_agent_sessions where session_id=target_session;
 if not found or not jioflow_private.manages_shop(a.shop_id) then raise exception 'Login request access denied.' using errcode='42501';end if;
 select * into p from public.jf_profiles where id=a.user_id;
 select jsonb_build_object('device',x.device_details141,'requested_at',x.requested_at,'approved_at',x.decided_at) into old_session from public.jf_agent_sessions x where x.user_id=a.user_id and x.shop_id=a.shop_id and x.status='approved' and x.session_id<>a.session_id order by x.decided_at desc nulls last limit 1;
 return jsonb_build_object('full_name',p.full_name,'email',p.email,'phone',p.phone,'user_code',p.user_code,'avatar_path',p.avatar_path,'role','Agent','shop_name',(select name from public.jf_shops where id=a.shop_id),'status',a.status,'requested_at',a.requested_at,'device',a.device_details141,'previous_session',old_session);
end$$;
revoke all on function public.jf_agent_device141(jsonb),public.jf_login_details141(uuid) from public,anon;
grant execute on function public.jf_agent_device141(jsonb),public.jf_login_details141(uuid) to authenticated;
commit;
