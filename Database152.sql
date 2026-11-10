begin;
-- One small change stamp per business/category/transaction; private, no customer payloads.
create table if not exists jioflow_private.jf_changes152(shop_id uuid not null,bucket text not null,version bigint not null,primary key(shop_id,bucket));
revoke all on jioflow_private.jf_changes152 from public,anon,authenticated;
create or replace function jioflow_private.jf_mark_changed152() returns trigger language plpgsql security definer set search_path='' as $$
declare scope_query text;relation_query text;begin
 relation_query:=case tg_op when 'INSERT' then 'select to_jsonb(n) data from new152 n' when 'DELETE' then 'select to_jsonb(o) data from old152 o' else 'select to_jsonb(n) data from new152 n union all select to_jsonb(o) data from old152 o' end;
 if tg_table_name='jf_agent_sessions' and tg_op='UPDATE' then relation_query:='select to_jsonb(n) data from new152 n where not exists(select 1 from old152 o where coalesce(to_jsonb(o)->>''session_id'',to_jsonb(o)->>''id'')=coalesce(to_jsonb(n)->>''session_id'',to_jsonb(n)->>''id'') and to_jsonb(o)->>''status''=to_jsonb(n)->>''status'')';end if;
 if tg_table_name='jf_profiles' then scope_query:='select distinct m.shop_id from ('||relation_query||') r join public.jf_memberships m on m.user_id=(r.data->>''id'')::uuid';
 elsif tg_table_name='jf_shops' then scope_query:='select distinct (r.data->>''id'')::uuid shop_id from ('||relation_query||') r';
 else scope_query:='select distinct (r.data->>''shop_id'')::uuid shop_id from ('||relation_query||') r';end if;
 execute 'insert into jioflow_private.jf_changes152 as t(shop_id,bucket,version) select s.shop_id,$1,$2 from ('||scope_query||') s where s.shop_id is not null on conflict(shop_id,bucket) do update set version=excluded.version where t.version<>excluded.version' using tg_argv[0],txid_current();
 return null;
end $$;
revoke all on function jioflow_private.jf_mark_changed152() from public,anon,authenticated;
do $triggers$
declare t text;b text;op text;refs text;begin
 foreach t in array array['jf_customers','jf_followups','jf_notes','jf_orders','jf_order_items','jf_payments','jf_shipments','jf_order_history','jf_products','jf_memberships','jf_profiles','jf_shops','jf_workspace_settings','jf_agent_sessions'] loop
 b:=case when t in('jf_memberships','jf_profiles','jf_shops','jf_agent_sessions') then 'directory' when t='jf_workspace_settings' then 'settings' when t='jf_products' then 'catalog' else 'records' end;
 foreach op in array array['INSERT','UPDATE','DELETE'] loop
 refs:=case op when 'INSERT' then 'new table as new152' when 'DELETE' then 'old table as old152' else 'new table as new152 old table as old152' end;
 execute format('drop trigger if exists %I on public.%I','jf_changes152_'||lower(op),t);
 execute format('create trigger %I after %s on public.%I referencing %s for each statement execute function jioflow_private.jf_mark_changed152(%L)','jf_changes152_'||lower(op),op,t,refs,b);
 end loop;end loop;
end $triggers$;
create or replace function public.jf_change_stamp152(target_shop uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare answer jsonb;begin
 if not coalesce(jioflow_private.session_allowed(),false) then raise exception 'Session access required.' using errcode='42501';end if;
 if target_shop is not null then
 if not coalesce(jioflow_private.reads_operations(target_shop),false) then raise exception 'Business access required.' using errcode='42501';end if;
 select coalesce(jsonb_object_agg(bucket,version::text),'{}'::jsonb) into answer from jioflow_private.jf_changes152 where shop_id=target_shop;
 else
 if not exists(select 1 from public.jf_profiles where id=auth.uid() and platform_role='creator' and deleted_at is null) then raise exception 'Creator access required.' using errcode='42501';end if;
 select coalesce(jsonb_object_agg(shop_id::text||':'||bucket,version::text),'{}'::jsonb) into answer from jioflow_private.jf_changes152;
 end if;return answer;
end $$;
revoke all on function public.jf_change_stamp152(uuid) from public,anon;
grant execute on function public.jf_change_stamp152(uuid) to authenticated;
do $heartbeat$
declare d text;begin
 d:=pg_get_functiondef('public.jf_panel_heartbeat(text,uuid,boolean)'::regprocedure);
 if position('change_stamp152' in d)=0 then
 if position('''allowed'',true,''gate'',gate' in d)=0 then raise exception 'Heartbeat shape changed; review before applying.';end if;
 d:=replace(d,'''allowed'',true,''gate'',gate','''change_stamp152'',case when coalesce((gate->>''is_agent'')::boolean,false) and gate->>''status''<>''approved'' then null else public.jf_change_stamp152(target_shop) end,''allowed'',true,''gate'',gate');execute d;
 end if;
end $heartbeat$;
commit;
