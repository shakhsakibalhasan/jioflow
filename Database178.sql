begin;
create or replace function public.jf_groups178(target_shop uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare answer jsonb;begin
 if not coalesce(jioflow_private.session_allowed(),false)
 or not coalesce(jioflow_private.reads_staff_operations(target_shop),false)
 or jioflow_private.agent_member(target_shop) is not null
 or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null)
 then raise exception 'Group access required.' using errcode='42501';end if;
 with gm as materialized(
 select distinct g.id group_id,m.id membership_id,p.full_name,p.email,
 (m.status='active' and p.active and p.deleted_at is null) active
 from public.jf_groups g join public.jf_group_members x on x.group_id=g.id and x.shop_id=g.shop_id
 join public.jf_memberships m on m.id=x.membership_id and m.shop_id=g.shop_id and m.role='agent' and m.status<>'removed'
 join public.jf_profiles p on p.id=m.user_id and p.deleted_at is null
 where g.shop_id=target_shop and g.active),counts as(
 select c.assigned_membership_id,count(*) assigned from public.jf_customers c
 where c.shop_id=target_shop and c.archived_at is null and c.assigned_membership_id in(select membership_id from gm)
 group by c.assigned_membership_id)
 select jsonb_build_object('groups',coalesce(jsonb_agg(to_jsonb(v) order by v.name,v.id),'[]'::jsonb)) into answer from(
 select g.id,g.name,g.active,
 coalesce((select jsonb_agg(m.membership_id order by m.membership_id) from gm m where m.group_id=g.id),'[]'::jsonb) members,
 (select count(*) from gm m where m.group_id=g.id) member_count,
 (select count(*) from gm m where m.group_id=g.id and m.active) active_count,
 coalesce((select sum(c.assigned) from gm m join counts c on c.assigned_membership_id=m.membership_id where m.group_id=g.id),0) assigned,
 coalesce((select jsonb_agg(jsonb_build_object('id',m.membership_id,'name',m.full_name,'email',m.email,'active',m.active,'assigned',coalesce(c.assigned,0)) order by m.full_name,m.membership_id) from gm m left join counts c on c.assigned_membership_id=m.membership_id where m.group_id=g.id),'[]'::jsonb) member_details
 from public.jf_groups g where g.shop_id=target_shop and g.active)v;
 return answer;
end $$;
revoke all on function public.jf_groups178(uuid) from public,anon;
grant execute on function public.jf_groups178(uuid) to authenticated;
commit;
