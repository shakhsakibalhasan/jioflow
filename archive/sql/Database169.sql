begin;
-- Keep existing workspace and own-shop group-management guards from Update 167.
do $patch$
declare d text;before169 text;after169 text;begin
 d:=pg_get_functiondef('public.jf_workspace_tools(uuid,text,jsonb)'::regprocedure);
 if position('groups169' in d)=0 then
 before169:=$old$   if gid is null then insert into public.jf_groups(shop_id,name) values(target_shop,trim(details->>'name')) returning id into gid;
   else update public.jf_groups set name=trim(details->>'name') where shop_id=target_shop and id=gid;if not found then raise exception 'Group not found.';end if;end if;$old$;
 after169:=$new$   -- groups169: serialize name checks, without overwriting an existing active group.
   perform pg_advisory_xact_lock(hashtextextended(target_shop::text||':groups169',0));
   if cardinality(agents)=0 then raise exception 'Select at least one Agent.';end if;
   if exists(select 1 from unnest(agents) a where not exists(select 1 from public.jf_memberships m where m.id=a and m.shop_id=target_shop and m.status='active')) then raise exception 'Choose active Agents in this business.';end if;
   if exists(select 1 from public.jf_groups g where g.shop_id=target_shop and lower(trim(g.name))=lower(trim(details->>'name')) and g.active and (gid is null or g.id<>gid)) then
    raise exception 'A group with this name already exists. Edit that group or choose another name.';
   end if;
   if gid is null then
    select g.id into gid from public.jf_groups g where g.shop_id=target_shop and lower(trim(g.name))=lower(trim(details->>'name')) and not g.active order by g.id limit 1 for update;
    if gid is null then insert into public.jf_groups(shop_id,name) values(target_shop,trim(details->>'name')) returning id into gid;
    else update public.jf_groups set active=true,name=trim(details->>'name') where shop_id=target_shop and id=gid;end if;
   else update public.jf_groups set name=trim(details->>'name') where shop_id=target_shop and id=gid;if not found then raise exception 'Group not found.';end if;end if;$new$;
 if position(before169 in d)=0 then raise exception 'Update 169 group-save patch target missing; apply Update 167 first.';end if;
 d:=replace(d,before169,after169);execute d;
 end if;
end $patch$;
commit;
