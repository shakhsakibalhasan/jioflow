begin;
create or replace function public.jf_payment_filter_match(amount_text text,ranges text) returns boolean language plpgsql immutable security invoker set search_path='' as $$
declare amount numeric;part text;lo numeric;hi numeric;
begin
 if nullif(ranges,'') is null then return true;end if;
 amount_text:=regexp_replace(regexp_replace(amount_text,'[৳,[:space:]]','','g'),'^(BDT|Tk)|(BDT|Tk)$','','gi');
 if amount_text is null or amount_text !~ '^[0-9]+([.][0-9]{1,2})?$' then return false;end if;
 amount:=amount_text::numeric;
 if ranges like 'exact:%' then
  if ranges !~ '^exact:[0-9]{1,12}([.][0-9]{1,2})?$' then raise exception 'Invalid exact payment amount.';end if;
  return amount=substring(ranges from 7)::numeric;
 end if;
 foreach part in array string_to_array(ranges,',') loop
  if part not in('0:500','100:500','500:1000','1000:2000','2000:3000','3000:4000','4000:5000','5000:6000','6000:7000','7000:8000','8000:9000','9000:10000') then raise exception 'Invalid payment range.';end if;
  lo:=case when part='100:500' then 0 else split_part(part,':',1)::numeric end;hi:=split_part(part,':',2)::numeric;
  if amount>=lo and (amount<hi or hi=10000 and amount=10000) then return true;end if;
 end loop;return false;
end$$;
revoke all on function public.jf_payment_filter_match(text,text) from public,anon;
grant execute on function public.jf_payment_filter_match(text,text) to authenticated;

do $patch$
declare r record;d text;changed text;allowed text:=$list$p not in('0:500','100:500','500:1000','1000:2000','2000:3000','3000:4000','4000:5000','5000:6000','6000:7000','7000:8000','8000:9000','9000:10000')$list$;
begin
 for r in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.prokind='f' and p.proname like 'jf_%' loop
  d:=pg_get_functiondef(r.oid);changed:=d;
  if position('exact_validator96' in d)=0 and position(allowed in d)>0 then
   changed:=replace(d,allowed,'(/*exact_validator96*/ p !~ ''^exact:[0-9]{1,12}([.][0-9]{1,2})?$'' and '||allowed||')');
  end if;
  if changed<>d then execute changed;end if;
 end loop;
end $patch$;
commit;
