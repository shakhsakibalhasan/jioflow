begin;
create or replace function public.jf_bulk_unassign153(target_shop uuid,customer_ids uuid[],reason_tag text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare ids uuid[];tag text:=nullif(trim(reason_tag),'');settings jsonb;changed integer;begin
 if not coalesce(jioflow_private.session_allowed(),false) or not coalesce(jioflow_private.reads_staff_operations(target_shop),false) or not coalesce(jioflow_private.has_permission(target_shop,'assign'),false) or jioflow_private.agent_member(target_shop) is not null or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null) then raise exception 'Distribution permission required.' using errcode='42501';end if;
 ids:=array(select distinct x from unnest(customer_ids) x where x is not null);
 if cardinality(ids)=0 then raise exception 'Select assigned customers first.';end if;
 if cardinality(ids)>10000 then raise exception 'Select up to 10,000 customers per unassign action.';end if;
 settings:=public.jf_status_settings(target_shop);
 if tag is not null and not exists(select 1 from jsonb_array_elements(settings->'tags') t where t->>'name'=tag and (t->>'active')::boolean) then raise exception 'Choose an active Unassign Tag from Workspace Settings.';end if;
 perform 1 from public.jf_customers where shop_id=target_shop and id=any(ids) order by id for update;
 if (select count(*) from public.jf_customers where shop_id=target_shop and archived_at is null and id=any(ids))<>cardinality(ids) then raise exception 'A selected customer is unavailable in this business.';end if;
 update public.jf_customers set assigned_membership_id=null,unassignment_tag=coalesce(tag,''),updated_at=now()
 where shop_id=target_shop and id=any(ids) and assigned_membership_id is not null;
 get diagnostics changed=row_count;
 return jsonb_build_object('unassigned',changed,'already_unassigned',cardinality(ids)-changed,'tag',tag);
end $$;
revoke all on function public.jf_bulk_unassign153(uuid,uuid[],text) from public,anon;
grant execute on function public.jf_bulk_unassign153(uuid,uuid[],text) to authenticated;
commit;
