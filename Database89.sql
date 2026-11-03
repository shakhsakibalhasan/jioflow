begin;
create index if not exists jf_history_stage_pending on public.jf_history_stage(job_id,row_number) where not done;
-- Private helper is callable only by the guarded SECURITY DEFINER import functions.
do $patch$
declare d text;guard text:=$guard$if not jioflow_private.has_permission(target_shop,'assign') then raise exception 'Customer editing is not permitted.' using errcode='42501'; end if;$guard$;
begin
 d:=pg_get_functiondef('public.jf_save_customer(uuid,uuid,jsonb)'::regprocedure);
 if position(guard in d)=0 then raise exception 'Customer function changed; review import helper before applying.';end if;
 d:=replace(d,'public.jf_save_customer(', 'jioflow_private.jf_import_customer89(');
 d:=replace(d,guard,'');d:=replace(d,'jioflow_private.agent_member(target_shop)','null::uuid');execute d;
end $patch$;
revoke all on function jioflow_private.jf_import_customer89(uuid,uuid,jsonb) from public,anon,authenticated;
do $patch$
declare d text;
begin
 d:=pg_get_functiondef('public.jf_history_import(uuid,text,jsonb)'::regprocedure);
 d:=replace(d,'public.jf_save_customer(target_shop,null,','jioflow_private.jf_import_customer89(target_shop,null,');
 if position('jsonb_array_length(details->''rows'')>2000' in d)=0 then d:=replace(d,'jsonb_array_length(details->''rows'')>200','jsonb_array_length(details->''rows'')>2000');end if;
 d:=replace(d,'limit 100 for update loop', 'limit 500 for update loop');
 -- A soft per-request time budget commits finished rows instead of running into the statement timeout.
 if position('started89' in d)=0 then
 d:=replace(d,'declare jid uuid;', 'declare started89 timestamptz:=clock_timestamp();jid uuid;');
 d:=replace(d,E'   end;\n  end loop;', E'   end;\n   exit when clock_timestamp()-started89 > interval ''4 seconds'';\n  end loop;');
 end if;
 execute d;
 d:=pg_get_functiondef('public.jf_save_customer_batch(uuid,jsonb)'::regprocedure);
 d:=replace(d,'public.jf_save_customer(target_shop,null,','jioflow_private.jf_import_customer89(target_shop,null,');
 d:=replace(d,'between 1 and 100','between 1 and 500');d:=replace(d,'Send 1–100 customers','Send 1–500 customers');execute d;
end $patch$;
commit;
