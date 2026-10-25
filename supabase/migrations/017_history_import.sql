begin;
create table public.jf_order_history(
 id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.jf_shops(id) on delete cascade,
 customer_id uuid not null references public.jf_customers(id) on delete cascade,external_id text not null check(length(external_id) between 1 and 200),
 details jsonb not null,updated_at timestamptz not null default now(),unique(shop_id,external_id)
);
create index jf_order_history_customer on public.jf_order_history(shop_id,customer_id,updated_at desc);
create table public.jf_history_jobs(
 id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.jf_shops(id) on delete cascade,
 requested_by uuid references public.jf_profiles(id),file_name text not null,status text not null default 'uploading' check(status in('uploading','ready','processing','completed','cancelled')),
 staged integer not null default 0,processed integer not null default 0,rejected integer not null default 0,created_at timestamptz not null default now()
);
create table public.jf_history_stage(job_id uuid references public.jf_history_jobs(id) on delete cascade,row_number integer not null,payload jsonb not null,done boolean not null default false,error text,primary key(job_id,row_number));
alter table public.jf_order_history enable row level security;alter table public.jf_history_jobs enable row level security;alter table public.jf_history_stage enable row level security;
revoke all on public.jf_order_history,public.jf_history_jobs,public.jf_history_stage from anon,authenticated;
grant select on public.jf_order_history to authenticated;
create policy jf_history_read on public.jf_order_history for select to authenticated using(jioflow_private.can_read_customer(shop_id,customer_id));
create function public.jf_history_import(target_shop uuid,action text,details jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare jid uuid;j public.jf_history_jobs%rowtype;r record;cid uuid;oldcid uuid;n integer;bad integer:=0;good integer:=0;x jsonb;
begin
 if not jioflow_private.has_permission(target_shop,'assign') or not jioflow_private.has_permission(target_shop,'import') or not jioflow_private.reads_staff_operations(target_shop) then raise exception 'Import permission required.' using errcode='42501';end if;
 if action='list' then return coalesce((select jsonb_agg(to_jsonb(t)) from(select * from public.jf_history_jobs where shop_id=target_shop order by created_at desc limit 50)t),'[]');end if;
 if action='create' then
  if length(trim(coalesce(details->>'file_name',''))) not between 1 and 250 then raise exception 'Invalid file name.';end if;
  insert into public.jf_history_jobs(shop_id,requested_by,file_name) values(target_shop,auth.uid(),details->>'file_name') returning id into jid;return jsonb_build_object('id',jid);
 end if;
 jid:=(details->>'job_id')::uuid;select * into j from public.jf_history_jobs where shop_id=target_shop and id=jid for update;if not found then raise exception 'Import job not found.';end if;
 if action='stage' then
  if j.status<>'uploading' or jsonb_typeof(details->'rows')<>'array' or jsonb_array_length(details->'rows')>200 or (details->>'offset')::integer<0 then raise exception 'Invalid upload chunk or job state.';end if;
  n:=(details->>'offset')::integer;for x in select * from jsonb_array_elements(details->'rows') loop
   insert into public.jf_history_stage(job_id,row_number,payload) values(jid,n,x) on conflict do nothing;n:=n+1;
  end loop;
  update public.jf_history_jobs set staged=(select count(*) from public.jf_history_stage where job_id=jid) where id=jid;
 elsif action='ready' then
  if j.status<>'uploading' or j.staged=0 then raise exception 'Upload rows before importing.';end if;
  update public.jf_history_jobs set status='ready' where id=jid;
 elsif action='cancel' then update public.jf_history_jobs set status='cancelled' where id=jid;
 elsif action='process' then
  if j.status not in('ready','processing') then return to_jsonb(j);end if;
  update public.jf_history_jobs set status='processing' where id=jid;
  for r in select * from public.jf_history_stage where job_id=jid and not done order by row_number limit 100 for update loop
   begin
    if length(trim(coalesce(r.payload->>'external_id',''))) not between 1 and 200 or jsonb_typeof(r.payload->'customer')<>'object' then raise exception 'Invoice / Order ID and customer required.';end if;
    cid:=public.jf_save_customer(target_shop,null,r.payload->'customer');
    select customer_id into oldcid from public.jf_order_history where shop_id=target_shop and external_id=trim(r.payload->>'external_id') for update;
    if oldcid is not null and oldcid<>cid then raise exception 'This Order ID belongs to a different phone.';end if;
    insert into public.jf_order_history(shop_id,customer_id,external_id,details) values(target_shop,cid,trim(r.payload->>'external_id'),r.payload-'customer'-'external_id') on conflict(shop_id,external_id) do update set details=excluded.details,updated_at=now();
    update public.jf_history_stage set done=true,payload='{}' where job_id=jid and row_number=r.row_number;good:=good+1;
   exception when others then
    update public.jf_history_stage set done=true,error=case when sqlstate in('22023','P0001') then left(sqlerrm,250) else 'Row validation failed ('||sqlstate||')' end,payload='{}' where job_id=jid and row_number=r.row_number;bad:=bad+1;
   end;
  end loop;
  update public.jf_history_jobs set processed=processed+good+bad,rejected=rejected+bad,status=case when not exists(select 1 from public.jf_history_stage where job_id=jid and not done) then 'completed' else 'processing' end where id=jid;
 elsif action='errors' then return coalesce((select jsonb_agg(jsonb_build_object('row',row_number+2,'error',error)) from(select row_number,error from public.jf_history_stage where job_id=jid and error is not null order by row_number limit 200)t),'[]');
 else raise exception 'Unknown import action.';end if;
 return(select to_jsonb(t) from public.jf_history_jobs t where id=jid);
end $$;
revoke all on function public.jf_history_import(uuid,text,jsonb) from public,anon,authenticated;grant execute on function public.jf_history_import(uuid,text,jsonb) to authenticated;
insert into public.jf_schema_versions(version) values('017_history_import');commit;
