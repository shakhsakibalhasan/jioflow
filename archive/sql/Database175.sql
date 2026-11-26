begin;
create or replace function public.jf_followup_tags174(target_shop uuid,section_name text default null,definitions jsonb default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare base jsonb;sections jsonb;regular jsonb;permanent jsonb;reasons jsonb;v jsonb;item jsonb;canonical jsonb;sid text;begin
 base:=public.jf_status_settings(target_shop);
 if definitions is not null then
 if not coalesce((base->>'can_configure')::boolean,false) then raise exception 'Status configuration permission required.' using errcode='42501';end if;
 if section_name is null or section_name not in('unassigned','assigned','completed','permanent','all') then raise exception 'Choose a Follow-up section.';end if;
 if jsonb_typeof(definitions)<>'array' or octet_length(definitions::text)>100000 then raise exception 'Invalid tag list.';end if;
 if exists(select 1 from jsonb_array_elements(definitions) x where jsonb_typeof(x)<>'object' or coalesce(x->>'id','')!~'^[a-zA-Z0-9-]{1,80}$' or length(trim(coalesce(x->>'name',''))) not between 1 and 120 or coalesce(x->>'color','')!~'^#[a-fA-F0-9]{6}$' or jsonb_typeof(x->'active') is distinct from 'boolean' or coalesce(x->>'mode','') not in('workflow','reason','never') or length(trim(coalesce(x->>'value',''))) not between 1 and 120 or (section_name='unassigned' and x->>'mode'='workflow') or (section_name<>'unassigned' and x->>'mode'<>'workflow')) then raise exception 'Each tag needs a valid name, color, filter value and active flag.';end if;
 if exists(select 1 from jsonb_array_elements(definitions) x group by x->>'id' having count(*)>1) or exists(select 1 from jsonb_array_elements(definitions) x where (x->>'active')::boolean group by lower(trim(x->>'name')) having count(*)>1) or exists(select 1 from jsonb_array_elements(definitions) x where (x->>'active')::boolean group by x->>'value',x->>'mode' having count(*)>1) then raise exception 'Use unique tag names, filter values and IDs.';end if;
 perform 1 from public.jf_shops where id=target_shop for update;
 base:=public.jf_status_settings(target_shop);
 -- Register new filter values as real selectable statuses/reasons, through the existing guarded validator.
 canonical:=case section_name when 'unassigned' then base->'tags' when 'permanent' then base->'permanent_statuses' else base->'statuses' end;
 for item in select * from jsonb_array_elements(definitions) x where (x->>'active')::boolean and x->>'mode'<>'never' loop
 if not exists(select 1 from jsonb_array_elements(canonical) x where x->>'name'=trim(item->>'value')) then
 canonical:=canonical||jsonb_build_array(jsonb_build_object('id','section-'||gen_random_uuid()::text,'name',trim(item->>'value'),'color',item->>'color','active',true,'kind',coalesce(item->>'kind','processing'),'days',coalesce((item->>'days')::int,0)));
 end if;end loop;
 select coalesce(jsonb_agg(case when exists(select 1 from jsonb_array_elements(definitions) d where (d->>'active')::boolean and d->>'mode'<>'never' and trim(d->>'value')=x->>'name') then jsonb_set(x,'{active}','true') else x end order by n),'[]') into canonical from jsonb_array_elements(canonical) with ordinality t(x,n);
 if section_name='unassigned' then perform public.jf_status_settings(target_shop,null,canonical,null);
 elsif section_name='permanent' then perform public.jf_status_settings(target_shop,null,null,canonical);
 else perform public.jf_status_settings(target_shop,canonical,null,null);end if;
 insert into public.jf_workspace_settings(shop_id,value) values(target_shop,jsonb_build_object('followup_sections174',jsonb_build_object(section_name,definitions))) on conflict(shop_id) do update set value=jsonb_set(public.jf_workspace_settings.value,'{followup_sections174}',coalesce(public.jf_workspace_settings.value->'followup_sections174','{}')||jsonb_build_object(section_name,definitions)),updated_at=now();
 base:=public.jf_status_settings(target_shop);
 end if;
 select coalesce(s.value->'followup_sections174','{}') into sections from public.jf_workspace_settings s where s.shop_id=target_shop;sections:=coalesce(sections,'{}');
 select coalesce(jsonb_agg(x||jsonb_build_object('mode','workflow','value',x->>'name') order by case x->>'kind' when 'processing' then case when x->>'name'='Processing' then 0 else 2 end when 'confirm' then 1 else 2 end,n),'[]') into regular from jsonb_array_elements(base->'statuses') with ordinality t(x,n);
 select coalesce(jsonb_agg(x||jsonb_build_object('mode','workflow','value',x->>'name') order by n),'[]') into permanent from jsonb_array_elements(base->'permanent_statuses') with ordinality t(x,n);
 select jsonb_build_array(jsonb_build_object('id','never-assigned','name','Never Assigned','color','#64748b','active',true,'mode','never','value','never'))||coalesce(jsonb_agg(x||jsonb_build_object('mode','reason','value',x->>'name') order by n),'[]') into reasons from jsonb_array_elements(base->'tags') with ordinality t(x,n);
 sections:=jsonb_set(sections,'{unassigned}',jsonb_build_array(jsonb_build_object('id','never-assigned','name','Never Assigned','color','#64748b','active',true,'mode','never','value','never'))||coalesce((select jsonb_agg(x) from jsonb_array_elements(coalesce(sections->'unassigned',reasons)) x where x->>'mode'<>'never'),'[]'));
 return base||jsonb_build_object('sections174',jsonb_build_object('unassigned',reasons,'assigned',regular,'completed',regular,'permanent',permanent,'all',regular)||sections);
end $$;
revoke all on function public.jf_followup_tags174(uuid,text,jsonb) from public,anon;
grant execute on function public.jf_followup_tags174(uuid,text,jsonb) to authenticated;



create or replace function public.jf_bulk_unassign153(target_shop uuid,customer_ids uuid[],reason_tag text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare ids uuid[];tag text:=nullif(trim(reason_tag),'');settings jsonb;changed integer;begin
 if not coalesce(jioflow_private.session_allowed(),false) or not coalesce(jioflow_private.reads_staff_operations(target_shop),false) or not coalesce(jioflow_private.has_permission(target_shop,'assign'),false) or jioflow_private.agent_member(target_shop) is not null or not exists(select 1 from public.jf_shops where id=target_shop and active and archived_at is null) then raise exception 'Distribution permission required.' using errcode='42501';end if;
 ids:=array(select distinct x from unnest(customer_ids) x where x is not null);
 if cardinality(ids)=0 then raise exception 'Select assigned customers first.';end if;
 if cardinality(ids)>10000 then raise exception 'Select up to 10,000 customers per unassign action.';end if;
 if tag is null then raise exception 'Choose an Unassigned tag.';end if;
 settings:=public.jf_followup_tags174(target_shop);
 if tag is not null and not exists(select 1 from jsonb_array_elements(settings->'sections174'->'unassigned') t where t->>'mode'='reason' and coalesce(t->>'value',t->>'name')=tag and (t->>'active')::boolean) then raise exception 'Choose an active Unassign Tag from Workspace Settings.';end if;
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
