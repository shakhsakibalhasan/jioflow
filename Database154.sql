begin;
-- Only enrich returned order-page rows; preserve existing list guards and filters.
do $patch$
declare f record;d text;addition text;begin
 addition:=$add$
 if entity='orders' then
 select jsonb_set(result,'{rows}',coalesce(jsonb_agg(r.value||jsonb_build_object('customer_workflow154',c.workflow_label,'agent_outcome144',jsonb_build_object('customer',fu.customer_status130,'call',fu.call_status130)) order by r.ordinality),'[]'::jsonb)) into result
 from jsonb_array_elements(coalesce(result->'rows','[]'::jsonb)) with ordinality r(value,ordinality)
 left join public.jf_customers c on c.shop_id=target_shop and c.id=nullif(r.value->>'customer_id','')::uuid
 left join public.jf_followups fu on fu.shop_id=target_shop and fu.customer_id=c.id;
 end if;
 return result;
$add$;
 for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','jioflow_private') and p.proname in('jf_agent_page78','jf_workspace_page_rls73','jf_workspace_page_staff73') loop
 d:=pg_get_functiondef(f.oid);
 if position('customer_workflow154' in d)=0 then
 if position(' return result;' in d)=0 then raise exception 'Order page shape changed; review before applying154.';end if;
 d:=replace(d,' return result;',addition);execute d;
 end if;
 end loop;
end $patch$;
commit;
