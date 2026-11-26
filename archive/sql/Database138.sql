begin;
-- One committed record and its actual outcome in a single round trip.
-- Keep existing shop/import authorization, validation, locking and idempotency.
do $patch$
declare d text; old text;
begin
 d:=pg_get_functiondef('public.jf_history_import(uuid,text,jsonb)'::regprocedure);
 if position($s$action='append138'$s$ in d)=0 then
  if position($s$action='append136'$s$ in d)=0 then raise exception 'Apply Database136.sql first.';end if;
  d:=replace(d,$s$if action='append136' then$s$,$s$if action in('append136','append138') then
  if action='append138' and (jsonb_typeof(details->'rows') is distinct from 'array' or jsonb_array_length(details->'rows')<>1) then raise exception 'Send exactly one record.';end if;$s$);
  old:=$s$return(select to_jsonb(t) from public.jf_history_jobs t where id=jid);
 elsif action='stage' then$s$;
  if position(old in d)=0 then raise exception 'Review changed append return before Update138.';end if;
  d:=replace(d,old,$s$if action='append138' then
   return(select to_jsonb(t)||jsonb_build_object('result138',(select jsonb_build_object('row',s.row_number+2,'result135',s.result135,'status',s.outcome135,'error',s.error) from public.jf_history_stage s where s.job_id=jid and s.row_number=(details->>'offset')::int and s.done)) from public.jf_history_jobs t where id=jid);
  end if;
  return(select to_jsonb(t) from public.jf_history_jobs t where id=jid);
 elsif action='stage' then$s$);
  execute d;
 end if;
end$patch$;
commit;
