begin;
-- Existing job/shop permissions, row validation, deterministic offsets and retry
-- handling remain in place. Commit up to 500 records per request.
do $patch$
declare d text;anchor text;begin
 d:=pg_get_functiondef('public.jf_history_import(uuid,text,jsonb)'::regprocedure);
 if position($s$action='append145'$s$ in d)=0 then
  anchor:=$s$if action in('append136','append138') then$s$;
  if position(anchor in d)=0 then raise exception 'Apply Database138.sql before Update145.';end if;
  d:=replace(d,anchor,$s$if action in('append136','append138','append145') then$s$);
  d:=replace(d,$s$if action='append138' then
   return$s$,$s$if action='append145' then
   return(select to_jsonb(t)||jsonb_build_object('results145',(select coalesce(jsonb_agg(jsonb_build_object('row',s.row_number+2,'result135',s.result135,'status',s.outcome135,'error',s.error) order by s.row_number),'[]') from public.jf_history_stage s where s.job_id=jid and s.row_number>=(details->>'offset')::int and s.row_number<(details->>'offset')::int+jsonb_array_length(details->'rows') and s.done)) from public.jf_history_jobs t where id=jid);
  end if;
  if action='append138' then
   return$s$);
  execute d;
 end if;
end $patch$;
-- Order ID is the duplicate key. Phone is the customer identity, so a new
-- order on an existing phone updates that customer and adds order history.
do $patch$
declare d text;anchor text;begin
 d:=pg_get_functiondef('public.jf_history_import(uuid,text,jsonb)'::regprocedure);
 if position('duplicate_order145' in d)=0 then
 anchor:=$s$cid:=jioflow_private.jf_import_customer89(target_shop,null,r.payload->'customer');$s$;
 if position(anchor in d)=0 then raise exception 'Import customer write anchor changed; no changes applied.';end if;
 d:=replace(d,anchor,$s$-- duplicate_order145: do not mutate a customer for a skipped Order ID.
    perform pg_advisory_xact_lock(hashtextextended(target_shop::text||':'||trim(r.payload->>'external_id'),145));
    select customer_id into oldcid from public.jf_order_history where shop_id=target_shop and external_id=trim(r.payload->>'external_id');
    if oldcid is not null then
     update public.jf_history_stage set outcome135='skipped',done=true,payload='{}',error=null where job_id=jid and row_number=r.row_number;
     good:=good+1;continue;
    end if;
    result_outcome135:=case when exists(select 1 from public.jf_customers c where c.shop_id=target_shop and c.phone=jioflow_private.normalize_phone(r.payload->'customer'->>'phone')) then 'updated' else 'created' end;
    cid:=jioflow_private.jf_import_customer89(target_shop,null,r.payload->'customer');$s$);
 d:=regexp_replace(d,$re$result_outcome135:=case when oldcid is null then 'created' when exists\([^\n]+then 'skipped' else 'updated' end;$re$,'');
 d:=replace(d,$s$outcome135=case when oldcid is null then 'created' when result_outcome135='skipped' then 'skipped' else 'updated' end$s$,$s$outcome135=result_outcome135$s$);
 execute d;
 end if;
 -- A customer-only file has no Order ID: matching phone means Updated.
 d:=pg_get_functiondef('public.jf_save_customer_batch(uuid,jsonb)'::regprocedure);
 d:=regexp_replace(d,$re$result135:=case when existing135.id is null then 'created' when [^\n]+then 'skipped' else 'updated' end;$re$,$s$result135:=case when existing135.id is null then 'created' else 'updated' end;$s$);
 execute d;
end $patch$;
commit;
