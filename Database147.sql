begin;
-- Imported numeric dates are MM/DD/YYYY, including optional Excel time suffix.
-- Original columns remain authoritative; blank Order Date stays unknown.
create or replace function public.jf_import_date100(data jsonb) returns date
language plpgsql stable security invoker set search_path='' as $fn$
declare v text;parts text[];begin
 if jsonb_typeof(data->'original_columns')='array' then
  select x->>'value' into v from jsonb_array_elements(data->'original_columns') with ordinality t(x,n)
  where lower(regexp_replace(x->>'column','[^a-zA-Z0-9]','','g')) in('orderdate','orderedat','date')
  order by case when lower(regexp_replace(x->>'column','[^a-zA-Z0-9]','','g'))='orderdate' then 0 else 1 end,n limit 1;
 else v:=coalesce(nullif(data->>'ordered_at',''),data->>'order_date');end if;
 v:=trim(v);
 if nullif(v,'') is null then return null;end if;
 parts:=regexp_match(v,'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})(?:[ T]\d{1,2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:\s*[APap][Mm])?)?$');
 if parts is not null then return make_date(parts[3]::int,parts[1]::int,parts[2]::int);end if;
 -- Malformed numeric dates must not silently fall back to a DMY interpretation.
 if v ~ '^\d{1,2}[/.-]\d{1,2}[/.-]\d{4}' then return null;end if;
 return public.jf_filter_date(v);
 exception when datetime_field_overflow or invalid_datetime_format then return null;
end $fn$;
revoke all on function public.jf_import_date100(jsonb) from public,anon;
grant execute on function public.jf_import_date100(jsonb) to authenticated;
-- Queue only dates that can be recovered from an existing valid source. Nothing
-- is invented from upload time; invalid or blank originals remain unknown.
create table if not exists jioflow_private.jf_date_repairs147(history_id uuid primary key);
revoke all on jioflow_private.jf_date_repairs147 from public,anon,authenticated;
insert into jioflow_private.jf_date_repairs147
 select h.id from public.jf_order_history h where public.jf_import_date100(h.details) is not null and h.import_order_date102 is distinct from public.jf_import_date100(h.details)
 on conflict do nothing;
-- SQL Editor/database owner only. Each call commits a small repair batch and
-- existing history/date/summary triggers keep all date-filter caches consistent.
create or replace function jioflow_private.repair_import_dates147(batch_size integer default 500) returns jsonb
language plpgsql security invoker set search_path='' as $fn$
declare ids uuid[];changed integer;remaining bigint;begin
 select array_agg(history_id) into ids from(select history_id from jioflow_private.jf_date_repairs147 order by history_id limit least(500,greatest(1,batch_size)) for update skip locked)t;
 update public.jf_order_history h set import_order_date102=public.jf_import_date100(h.details)
 where h.id=any(ids) and h.import_order_date102 is distinct from public.jf_import_date100(h.details);
 get diagnostics changed=row_count;
 delete from jioflow_private.jf_date_repairs147 where history_id=any(ids);
 select count(*) into remaining from jioflow_private.jf_date_repairs147;
 return jsonb_build_object('repaired',changed,'remaining',remaining);
end $fn$;
revoke all on function jioflow_private.repair_import_dates147(integer) from public,anon,authenticated;
commit;
-- One bounded repair immediately. Repeat Repair_Old_Dates147.sql until remaining=0.
select jioflow_private.repair_import_dates147(500);
