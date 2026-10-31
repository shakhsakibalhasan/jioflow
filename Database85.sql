begin;
create or replace function public.jf_delete_records(target_shop uuid,entity text,ids jsonb) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare affected integer;begin
 if not coalesce(jioflow_private.reads_staff_operations(target_shop),false) or not coalesce(jioflow_private.has_permission(target_shop,'assign'),false) then raise exception 'Owner/Admin record-management access required.' using errcode='42501';end if;
 if jsonb_typeof(ids) is distinct from 'array' or jsonb_array_length(ids) not between 1 and 500 then raise exception 'Choose 1–500 records per batch.';end if;
 if entity='customers' then update public.jf_customers set archived_at=now(),updated_at=now() where shop_id=target_shop and archived_at is null and id in(select value::uuid from jsonb_array_elements_text(ids));
 elsif entity='orders' then update public.jf_orders set archived_at=now(),updated_at=now() where shop_id=target_shop and archived_at is null and id in(select value::uuid from jsonb_array_elements_text(ids));
 else raise exception 'Choose customers or orders.';end if;
 get diagnostics affected=row_count;
 insert into jioflow_private.account_audit(actor_id,target_id,action,details) values(auth.uid(),auth.uid(),'bulk_archive_records',jsonb_build_object('shop_id',target_shop,'entity',entity,'ids',ids,'affected',affected));
 return jsonb_build_object('affected',affected);
end $$;
revoke all on function public.jf_delete_records(uuid,text,jsonb) from public,anon;
grant execute on function public.jf_delete_records(uuid,text,jsonb) to authenticated;
commit;
