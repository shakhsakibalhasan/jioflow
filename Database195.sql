begin;
-- A record explicitly returned to Processing is open again, even if previously contacted.
create or replace function jioflow_private.jf_unworked176(target_shop uuid,target_customer uuid)
returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.jf_customers c where c.shop_id=target_shop and c.id=target_customer and lower(trim(coalesce(c.workflow_label,'')))='processing')
or not exists(select 1 from public.jf_followups f where f.shop_id=target_shop and f.customer_id=target_customer and public.jf_followup_done139(f.status,f.call_outcome) and f.last_contact_at>=coalesce((select max(h.created_at) from jioflow_private.jf_assignment_history168 h where h.shop_id=target_shop and h.customer_id=target_customer and h.membership_id is not null),'-infinity'::timestamptz))
$$;
revoke all on function jioflow_private.jf_unworked176(uuid,uuid) from public,anon,authenticated;
-- Preserve removed duplicate group links for recovery; retain oldest active group.
lock table public.jf_group_members in share row exclusive mode;
create table if not exists jioflow_private.group_links_backup195(shop_id uuid,group_id uuid,membership_id uuid,saved_at timestamptz not null default now(),primary key(shop_id,group_id,membership_id));
revoke all on jioflow_private.group_links_backup195 from public,anon,authenticated;
with ranked as(select x.*,row_number() over(partition by x.shop_id,x.membership_id order by g.active desc,g.created_at,g.id) n from public.jf_group_members x join public.jf_groups g on g.id=x.group_id and g.shop_id=x.shop_id),removed as(delete from public.jf_group_members x using ranked r where r.n>1 and x.shop_id=r.shop_id and x.group_id=r.group_id and x.membership_id=r.membership_id returning x.*)
insert into jioflow_private.group_links_backup195(shop_id,group_id,membership_id) select shop_id,group_id,membership_id from removed on conflict do nothing;
create unique index if not exists jf_one_group_member195 on public.jf_group_members(shop_id,membership_id);
create or replace function jioflow_private.one_group_member195() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.jf_group_members x where x.shop_id=new.shop_id and x.membership_id=new.membership_id and x.group_id<>new.group_id) then raise exception 'This Agent already belongs to another group. Remove them from that group first.' using errcode='23505';end if;
 return new;
end $$;
revoke all on function jioflow_private.one_group_member195() from public,anon,authenticated;
drop trigger if exists one_group_member195 on public.jf_group_members;
create trigger one_group_member195 before insert or update on public.jf_group_members for each row execute function jioflow_private.one_group_member195();
-- Serialize group edits per shop and reject conflicts before the legacy ON CONFLICT clause.
do $$declare d text;begin
 d:=pg_get_functiondef('public.jf_workspace_tools(uuid,text,jsonb)'::regprocedure);
 if position('/*onegroup195*/' in d)=0 then
 d:=replace(d,$x$agents:=array(select x::uuid from jsonb_array_elements_text(coalesce(details->'members','[]')) x);$x$,$x$agents:=array(select x::uuid from jsonb_array_elements_text(coalesce(details->'members','[]')) x);
   /*onegroup195*/ perform 1 from public.jf_shops where id=target_shop for update;
   if exists(select 1 from public.jf_group_members x where x.shop_id=target_shop and x.membership_id=any(agents) and (gid is null or x.group_id<>gid)) then raise exception 'This Agent already belongs to another group. Remove them from that group first.' using errcode='23505';end if;$x$);
 if position('/*onegroup195*/' in d)=0 then raise exception 'Group save update could not be applied.';end if;
 execute d;
 end if;
end $$;
commit;
