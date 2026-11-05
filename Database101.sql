begin;
-- CSV numeric Order Date is MM/DD/YYYY. Original columns remain untouched.
-- One canonical date source for imported orders. Never use upload/Created At.
create or replace function public.jf_import_date100(data jsonb) returns date
language plpgsql stable security invoker set search_path='' as $fn$
declare v text; parts text[];
begin
 if jsonb_typeof(data->'original_columns')='array' then
  select x->>'value' into v from jsonb_array_elements(data->'original_columns') with ordinality t(x,n)
  where lower(regexp_replace(x->>'column','[^a-zA-Z0-9]','','g')) in('orderdate','orderedat','date')
  order by case when lower(regexp_replace(x->>'column','[^a-zA-Z0-9]','','g'))='orderdate' then 0 else 1 end,n limit 1;
  -- If original columns exist, absent/blank Order Date must stay unknown.
 else v:=coalesce(nullif(data->>'ordered_at',''),data->>'order_date');end if;
 v:=trim(v);
 if v ~ '^\d{1,2}[/.-]\d{1,2}[/.-]\d{4}$' then
  parts:=regexp_split_to_array(v,'[/.-]');
  return make_date(parts[3]::int,parts[1]::int,parts[2]::int);
 end if;
 return public.jf_filter_date(v);
 exception when datetime_field_overflow or invalid_datetime_format then return null;
end $fn$;
revoke all on function public.jf_import_date100(jsonb) from public,anon;
grant execute on function public.jf_import_date100(jsonb) to authenticated;
commit;
