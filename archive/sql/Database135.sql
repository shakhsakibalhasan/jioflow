begin;
-- Per-row import results remain behind the existing shop/import permission guard.
alter table public.jf_history_stage add column if not exists outcome135 text;
alter table public.jf_history_stage add column if not exists result135 jsonb;
create or replace function jioflow_private.import_result135() returns trigger language plpgsql set search_path='' as $$
begin
 if new.done and not old.done then
  new.outcome135:=coalesce(new.outcome135,case when new.error is null then 'updated' else 'failed' end);
  new.result135:=jsonb_build_object('name',old.payload->'customer'->>'full_name','phone',old.payload->'customer'->>'phone','address',old.payload->'customer'->>'address','order_id',old.payload->>'external_id');
 end if;return new;
end$$;
revoke all on function jioflow_private.import_result135() from public,anon,authenticated;
drop trigger if exists jf_import_result135 on public.jf_history_stage;
create trigger jf_import_result135 before update on public.jf_history_stage for each row execute function jioflow_private.import_result135();
do $patch$
declare d text;anchor text;
begin
 d:=pg_get_functiondef('public.jf_history_import(uuid,text,jsonb)'::regprocedure);
 if position('outcome135' in d)=0 then
  d:=replace(d,'declare ','declare outcome135 text; ');
  anchor:='    insert into public.jf_order_history(shop_id,customer_id,external_id,details)';
  if position(anchor in d)=0 then raise exception 'Review importer before applying Update135.';end if;
  d:=replace(d,anchor,$new$    outcome135:=case when oldcid is null then 'created' when exists(select 1 from public.jf_order_history h where h.shop_id=target_shop and h.external_id=trim(r.payload->>'external_id') and (h.details-'customer_snapshot105')=(r.payload-'customer'-'external_id')) then 'skipped' else 'updated' end;
    if outcome135<>'skipped' then
    insert into public.jf_order_history(shop_id,customer_id,external_id,details)$new$);
  d:=replace(d,'update public.jf_history_stage set done=true,payload=', 'end if; update public.jf_history_stage set outcome135=outcome135,done=true,payload=');
  -- Qualify the PL/pgSQL variable to avoid column/variable ambiguity.
  d:=replace(d,'outcome135=outcome135,','outcome135=case when oldcid is null then ''created'' when outcome135=''skipped'' then ''skipped'' else ''updated'' end,');
  d:=replace(d,'outcome135 text','result_outcome135 text');d:=replace(d,'outcome135:=','result_outcome135:=');d:=replace(d,'if outcome135<>''skipped''', 'if result_outcome135<>''skipped''' );d:=replace(d,'when outcome135=''skipped''', 'when result_outcome135=''skipped''' );
  d:=replace(d,'set done=true,error=','set outcome135=''failed'',done=true,error=');
  d:=replace(d,$str$if length(trim(coalesce(r.payload->>'external_id',''))) not between$str$,$new$if nullif(r.payload->>'validation_error135','') is not null then raise exception '%',left(r.payload->>'validation_error135',250);end if;
    if length(trim(coalesce(r.payload->>'external_id',''))) not between$new$);
  execute d;
 end if;
 d:=pg_get_functiondef('public.jf_history_import(uuid,text,jsonb)'::regprocedure);
 if position($str$action='results135'$str$ in d)=0 then
  d:=replace(d,$str$elsif action='errors' then$str$,$new$elsif action='results135' then
  return jsonb_build_object('matched',(select count(*) from public.jf_history_stage where job_id=jid and (coalesce(details->>'status','')='' or outcome135=details->>'status')),'total',j.staged,'processed',j.processed,'counts',(select coalesce(jsonb_object_agg(k,count135),'{}') from(select coalesce(outcome135,case when error is null then 'updated' else 'failed' end) k,count(*) count135 from public.jf_history_stage where job_id=jid and done group by 1)t),'rows',(select coalesce(jsonb_agg(to_jsonb(t)),'[]') from(select row_number+2 row,result135,coalesce(outcome135,case when done then case when error is null then 'updated' else 'failed' end else 'pending' end) status,error from public.jf_history_stage where job_id=jid and (coalesce(details->>'status','')='' or outcome135=details->>'status') order by row_number offset greatest(0,coalesce((details->>'offset')::int,0)) limit 200)t));
 elsif action='errors' then$new$);execute d;
 end if;
end$patch$;
-- Customer-only files return the same actual Created/Updated/Skipped result vocabulary.
do $patch$
declare d text;
begin
 d:=pg_get_functiondef('public.jf_save_customer_batch(uuid,jsonb)'::regprocedure);
 if position('results135' in d)=0 then
  d:=replace(d,'declare ', 'declare results135 jsonb:=''[]''; result135 text; existing135 public.jf_customers%rowtype; ');
  d:=replace(d,'loop perform ', $new$loop begin
   select * into existing135 from public.jf_customers where shop_id=target_shop and phone=jioflow_private.normalize_phone(row->>'phone');
   result135:=case when existing135.id is null then 'created' when existing135.archived_at is null and not exists(select 1 from jsonb_each_text(row) x where x.key in('full_name','address','email','district','area','source') and x.value<>'' and coalesce(to_jsonb(existing135)->>x.key,'') is distinct from x.value) then 'skipped' else 'updated' end;
   perform $new$);
  d:=replace(d,'saved:=saved+1;', $new$saved:=saved+1; results135:=results135||jsonb_build_array(jsonb_build_object('phone',row->>'phone','status',result135)); exception when others then results135:=results135||jsonb_build_array(jsonb_build_object('phone',row->>'phone','status','failed','error',case when sqlstate in('22023','P0001') then left(sqlerrm,250) else 'Row validation failed ('||sqlstate||')' end)); end;$new$);
  d:=replace(d,$str$jsonb_build_object('saved',saved)$str$,$str$jsonb_build_object('saved',saved,'processed135',jsonb_array_length(results135),'results135',results135)$str$);execute d;
 end if;
end$patch$;
-- Validated activity heartbeat; presence is not inferred from an old login approval.
create table if not exists jioflow_private.agent_presence135(user_id uuid not null,shop_id uuid not null,last_seen timestamptz not null,primary key(user_id,shop_id));
revoke all on jioflow_private.agent_presence135 from public,anon,authenticated;
create or replace function public.jf_presence135() returns void language plpgsql volatile security definer set search_path='' as $$
begin
 if not public.jf_session_status() then return;end if;
 insert into jioflow_private.agent_presence135(user_id,shop_id,last_seen)
 select a.user_id,a.shop_id,now() from public.jf_agent_sessions a join public.jf_memberships m on m.user_id=a.user_id and m.shop_id=a.shop_id and m.role='agent' and m.status='active' join public.jf_profiles p on p.id=a.user_id and p.active and p.deleted_at is null
 where a.user_id=auth.uid() and a.session_id::text=auth.jwt()->>'session_id' and a.status='approved'
 on conflict(user_id,shop_id) do update set last_seen=excluded.last_seen;
end$$;
revoke all on function public.jf_presence135() from public,anon,authenticated;grant execute on function public.jf_presence135() to authenticated;
do $patch$
declare d text;
begin
 d:=pg_get_functiondef('public.jf_panel_heartbeat(text,uuid,boolean)'::regprocedure);
 if position('jf_presence135' in d)=0 then d:=replace(d,'gate:=public.jf_agent_session(device_id);','gate:=public.jf_agent_session(device_id); perform public.jf_presence135();');execute d;end if;
 d:=pg_get_functiondef('public.jf_agent_report(uuid,uuid,timestamptz,timestamptz)'::regprocedure);
 if position($str$'online135'$str$ in d)=0 then
  d:=replace(d,$str$'active',p.active and m.status='active',$str$, $str$'active',p.active and m.status='active','phone',p.phone,'online135',p.active and m.status='active' and exists(select 1 from jioflow_private.agent_presence135 ap where ap.user_id=m.user_id and ap.shop_id=m.shop_id and ap.last_seen>now()-interval '90 seconds' and exists(select 1 from public.jf_agent_sessions a where a.user_id=m.user_id and a.shop_id=m.shop_id and a.status='approved')),$str$);execute d;
 end if;
end$patch$;
commit;
