begin;
-- Bounded processing and bulk duplicate detection, without raising global timeouts.
do $patch$
declare d text;anchor text;begin
 d:=pg_get_functiondef('public.jf_history_import(uuid,text,jsonb)'::regprocedure);
 if position('bounded_import146' in d)=0 then
  if position('duplicate_order145' in d)=0 then raise exception 'Apply Database145.sql first.';end if;
  d:=replace(d,'limit 500 for update loop',$s$limit least(500,greatest(1,coalesce((details->>'batch_size146')::int,50))) for update loop -- bounded_import146$s$);
  d:=replace(d,$s$interval '4 seconds'$s$,$s$interval '0.8 seconds'$s$);
  anchor:=$s$perform public.jf_history_import(target_shop,'process',jsonb_build_object('job_id',jid));$s$;
  if position(anchor in d)=0 then raise exception 'Streaming process anchor changed; no changes applied.';end if;
  d:=replace(d,anchor,$s$-- Skip existing Order IDs together before per-row customer work.
  update public.jf_history_stage s set outcome135='skipped',done=true,payload='{}',error=null
  where s.job_id=jid and not s.done and s.row_number>=(details->>'offset')::int and s.row_number<(details->>'offset')::int+jsonb_array_length(details->'rows')
   and nullif(s.payload->>'validation_error135','') is null and jsonb_typeof(s.payload->'customer')='object'
   and exists(select 1 from public.jf_order_history h where h.shop_id=target_shop and h.external_id=trim(s.payload->>'external_id'));
  get diagnostics n=row_count;
  update public.jf_history_jobs set processed=processed+n where id=jid;
  perform public.jf_history_import(target_shop,'process',jsonb_build_object('job_id',jid,'batch_size146',jsonb_array_length(details->'rows')));$s$);
  execute d;
 end if;
end $patch$;
commit;
