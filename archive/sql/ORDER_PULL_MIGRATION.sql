-- JioFlow Agent Take More Orders — safe opt-in, initially disabled
CREATE TABLE IF NOT EXISTS jioflow_private.jf_agent_pull_settings (
  shop_id uuid NOT NULL REFERENCES public.jf_shops(id),
  membership_id uuid NOT NULL REFERENCES public.jf_memberships(id),
  enabled boolean NOT NULL DEFAULT false,
  batch_size integer NOT NULL DEFAULT 20 CHECK (batch_size BETWEEN 1 AND 500),
  daily_limit integer NOT NULL DEFAULT 50 CHECK (daily_limit BETWEEN 1 AND 1000),
  require_empty boolean NOT NULL DEFAULT true,
  imported_statuses text[] NOT NULL DEFAULT ARRAY[]::text[],
  customer_tags text[] NOT NULL DEFAULT ARRAY[]::text[],
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (shop_id,membership_id)
);
CREATE TABLE IF NOT EXISTS jioflow_private.jf_agent_pull_history (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  shop_id uuid NOT NULL REFERENCES public.jf_shops(id),
  membership_id uuid NOT NULL REFERENCES public.jf_memberships(id),
  agent_id uuid NOT NULL REFERENCES public.jf_profiles(id),
  selection_type text NOT NULL CHECK(selection_type IN ('imported_status','customer_tag1')),
  selection_value text NOT NULL,
  quantity integer NOT NULL CHECK (quantity BETWEEN 1 AND 500),
  pulled_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS jf_agent_pull_history_daily_idx
  ON jioflow_private.jf_agent_pull_history(shop_id,membership_id,pulled_at);
CREATE INDEX IF NOT EXISTS jf_order_history_pull_latest_idx
  ON public.jf_order_history(shop_id,customer_id,updated_at DESC);
ALTER TABLE jioflow_private.jf_agent_pull_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE jioflow_private.jf_agent_pull_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON jioflow_private.jf_agent_pull_settings, jioflow_private.jf_agent_pull_history FROM PUBLIC, anon, authenticated;

-- Creator / Owner / Admin may edit the chosen Agent's settings. Agent may only read their own.
CREATE OR REPLACE FUNCTION public.jf_agent_pull_config(
  target_shop uuid, target_membership uuid DEFAULT NULL, config jsonb DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $fn$
DECLARE staff boolean := coalesce(jioflow_private.reads_staff_operations(target_shop),false);
  self_member uuid := jioflow_private.agent_member(target_shop);
  member_id uuid; s jioflow_private.jf_agent_pull_settings%rowtype;
  used_count bigint := 0;
BEGIN
 IF NOT coalesce(jioflow_private.session_allowed(),false) THEN RAISE EXCEPTION 'Sign in required' USING errcode='42501'; END IF;
 member_id := coalesce(target_membership,self_member);
 IF member_id IS NULL OR (NOT staff AND member_id IS DISTINCT FROM self_member) THEN
   RAISE EXCEPTION 'Order Pull permission denied' USING errcode='42501';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.jf_memberships m JOIN public.jf_profiles p ON p.id=m.user_id
    WHERE m.id=member_id AND m.shop_id=target_shop AND m.role='agent'
      AND m.status='active' AND p.active AND p.deleted_at IS NULL) THEN
   RAISE EXCEPTION 'Active Agent not found.' USING errcode='42501';
 END IF;
 IF config IS NOT NULL THEN
   IF NOT staff OR NOT coalesce(jioflow_private.has_permission(target_shop,'users'),false) THEN
     RAISE EXCEPTION 'Admin permission required.' USING errcode='42501'; END IF;
   IF jsonb_typeof(config)<>'object' OR EXISTS(
     SELECT 1 FROM jsonb_object_keys(config) k
     WHERE k NOT IN ('enabled','batch_size','daily_limit','require_empty','imported_statuses','customer_tags')
   ) THEN RAISE EXCEPTION 'Unexpected Order Pull setting'; END IF;
   IF jsonb_typeof(config->'imported_statuses')<>'array' OR jsonb_typeof(config->'customer_tags')<>'array' THEN
     RAISE EXCEPTION 'Choose an array of imported statuses and customer tags.'; END IF;
   IF jsonb_array_length(config->'imported_statuses')>50 OR jsonb_array_length(config->'customer_tags')>50 THEN
     RAISE EXCEPTION 'Too many Pull options'; END IF;
   IF EXISTS(SELECT 1 FROM jsonb_array_elements(config->'imported_statuses'||config->'customer_tags') v
      WHERE jsonb_typeof(v)<>'string' OR length(trim(v#>>'{}')) NOT BETWEEN 1 AND 120) THEN
     RAISE EXCEPTION 'Invalid option'; END IF;
   INSERT INTO jioflow_private.jf_agent_pull_settings AS a
     (shop_id,membership_id,enabled,batch_size,daily_limit,require_empty,imported_statuses,customer_tags)
   VALUES(target_shop,member_id,coalesce((config->>'enabled')::boolean,false),
     (config->>'batch_size')::int,(config->>'daily_limit')::int,
     coalesce((config->>'require_empty')::boolean,true),
     ARRAY(SELECT v#>>'{}' FROM jsonb_array_elements(config->'imported_statuses') v),
     ARRAY(SELECT v#>>'{}' FROM jsonb_array_elements(config->'customer_tags') v))
   ON CONFLICT(shop_id,membership_id) DO UPDATE SET
     enabled=EXCLUDED.enabled,batch_size=EXCLUDED.batch_size,daily_limit=EXCLUDED.daily_limit,
     require_empty=EXCLUDED.require_empty,imported_statuses=EXCLUDED.imported_statuses,
     customer_tags=EXCLUDED.customer_tags,updated_at=now();
 END IF;
 SELECT * INTO s FROM jioflow_private.jf_agent_pull_settings
 WHERE shop_id=target_shop AND membership_id=member_id;
 SELECT coalesce(sum(quantity),0) INTO used_count FROM jioflow_private.jf_agent_pull_history h
 WHERE h.shop_id=target_shop AND h.membership_id=member_id
 AND h.pulled_at >= (date_trunc('day',now() AT TIME ZONE 'Asia/Dhaka') AT TIME ZONE 'Asia/Dhaka')
 AND h.pulled_at < ((date_trunc('day',now() AT TIME ZONE 'Asia/Dhaka')+interval '1 day') AT TIME ZONE 'Asia/Dhaka');
 RETURN jsonb_build_object('enabled',coalesce(s.enabled,false),'batch_size',coalesce(s.batch_size,20),
   'daily_limit',coalesce(s.daily_limit,50),'require_empty',coalesce(s.require_empty,true),
   'imported_statuses',coalesce(to_jsonb(s.imported_statuses),'[]'::jsonb),
   'customer_tags',coalesce(to_jsonb(s.customer_tags),'[]'::jsonb),
   'used_today',used_count,'remaining',greatest(0,coalesce(s.daily_limit,50)-used_count),
   'available_statuses',(SELECT coalesce(jsonb_agg(status ORDER BY status),'[]'::jsonb) FROM
      (SELECT DISTINCT trim(h.details->>'status') status FROM public.jf_order_history h
       WHERE h.shop_id=target_shop AND nullif(trim(h.details->>'status'),'') IS NOT NULL LIMIT 100) src),
   'available_tags',(SELECT coalesce(jsonb_agg(tag ORDER BY tag),'[]'::jsonb) FROM
      (SELECT DISTINCT trim(coalesce(nullif(h.details->>'reference_tag',''),nullif(h.details->>'customer_tag_1',''),
        nullif(h.details->>'custom_tag',''),nullif(h.details->>'tag1',''))) tag
       FROM public.jf_order_history h WHERE h.shop_id=target_shop
       AND nullif(trim(coalesce(nullif(h.details->>'reference_tag',''),nullif(h.details->>'customer_tag_1',''),
          nullif(h.details->>'custom_tag',''),nullif(h.details->>'tag1',''))),'') IS NOT NULL LIMIT 100) tags));
END $fn$;
REVOKE ALL ON FUNCTION public.jf_agent_pull_config(uuid,uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.jf_agent_pull_config(uuid,uuid,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.jf_agent_pull_take(
 target_shop uuid, selection_type text, selection_value text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $fn$
DECLARE mid uuid := jioflow_private.agent_member(target_shop);
  cfg jioflow_private.jf_agent_pull_settings%rowtype;
  count_today bigint; amount int; assigned_count int;
BEGIN
 IF mid IS NULL OR NOT coalesce(jioflow_private.session_allowed(),false)
 THEN RAISE EXCEPTION 'Order Pull is not allowed for this approved Agent session.' USING errcode='42501'; END IF;
 IF selection_type NOT IN ('imported_status','customer_tag1') OR selection_value IS NULL
  OR length(trim(selection_value)) NOT BETWEEN 1 AND 120 THEN
   RAISE EXCEPTION 'Choose a valid Pull option'; END IF;
 SELECT * INTO cfg FROM jioflow_private.jf_agent_pull_settings
 WHERE shop_id=target_shop AND membership_id=mid FOR UPDATE;
 IF NOT FOUND OR NOT cfg.enabled THEN RAISE EXCEPTION 'Admin has not enabled Take More Orders.' USING errcode='42501'; END IF;
 IF (selection_type='imported_status' AND NOT selection_value=ANY(cfg.imported_statuses))
 OR (selection_type='customer_tag1' AND NOT selection_value=ANY(cfg.customer_tags)) THEN
   RAISE EXCEPTION 'Selection was not approved by Admin.' USING errcode='42501'; END IF;
 IF cfg.require_empty AND EXISTS(
   SELECT 1 FROM public.jf_customers c
   WHERE c.shop_id=target_shop AND c.assigned_membership_id=mid AND c.archived_at IS NULL
     AND NOT c.permanent AND jioflow_private.jf_unworked176(target_shop,c.id)
     AND NOT EXISTS(SELECT 1 FROM public.jf_followups f WHERE f.shop_id=target_shop
       AND f.customer_id=c.id AND f.status='callback' AND f.callback_at>now())
 ) THEN RAISE EXCEPTION 'Complete your current Processing queue first.'; END IF;
 SELECT coalesce(sum(h.quantity),0) INTO count_today FROM jioflow_private.jf_agent_pull_history h
 WHERE h.shop_id=target_shop AND h.membership_id=mid
 AND h.pulled_at >= (date_trunc('day',now() AT TIME ZONE 'Asia/Dhaka') AT TIME ZONE 'Asia/Dhaka')
 AND h.pulled_at < ((date_trunc('day',now() AT TIME ZONE 'Asia/Dhaka')+interval '1 day') AT TIME ZONE 'Asia/Dhaka');
 amount:=least(cfg.batch_size,cfg.daily_limit-count_today);
 IF amount<=0 THEN RAISE EXCEPTION 'Daily Pull limit reached.'; END IF;
 WITH chosen AS (
  SELECT c.id FROM public.jf_customers c
  WHERE c.shop_id=target_shop AND c.assigned_membership_id IS NULL
   AND c.archived_at IS NULL AND NOT c.permanent
   AND EXISTS(SELECT 1 FROM (SELECT hist.details FROM public.jf_order_history hist
     WHERE hist.shop_id=c.shop_id AND hist.customer_id=c.id
     ORDER BY hist.updated_at DESC,hist.id DESC LIMIT 1) h
     WHERE true
     AND ((selection_type='imported_status' AND lower(trim(coalesce(h.details->>'status','')))=lower(trim(selection_value)))
      OR (selection_type='customer_tag1' AND lower(trim(coalesce(
        nullif(h.details->>'reference_tag',''),nullif(h.details->>'customer_tag_1',''),
        nullif(h.details->>'custom_tag',''),nullif(h.details->>'tag1',''),'')))=lower(trim(selection_value)))))
  ORDER BY c.updated_at,c.id LIMIT amount FOR UPDATE OF c SKIP LOCKED
 ),assigned AS (
   UPDATE public.jf_customers c SET assigned_membership_id=mid,workflow_label='Processing',
     unassignment_tag='',updated_at=now()
   FROM chosen WHERE c.id=chosen.id AND c.shop_id=target_shop AND c.assigned_membership_id IS NULL
   RETURNING c.id
 ) SELECT count(*) INTO assigned_count FROM assigned;
 IF assigned_count>0 THEN
 INSERT INTO jioflow_private.jf_agent_pull_history
 (shop_id,membership_id,agent_id,selection_type,selection_value,quantity)
 VALUES(target_shop,mid,auth.uid(),selection_type,selection_value,assigned_count);
 END IF;
 RETURN jsonb_build_object('assigned',assigned_count,'daily_limit',cfg.daily_limit,
   'remaining',cfg.daily_limit-count_today-assigned_count,'selection_type',selection_type,
   'selection_value',selection_value);
END $fn$;
REVOKE ALL ON FUNCTION public.jf_agent_pull_take(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.jf_agent_pull_take(uuid,text,text) TO authenticated;

-- Close the legacy, unlimited jf_workspace_tools('pull') path.
-- It is replaced by jf_agent_pull_take, which enforces Agent settings, limits and locks.
DO $old_pull$
DECLARE fn text; start_pos integer; end_pos integer; old_fragment text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO fn
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='jf_workspace_tools';
  IF fn IS NULL THEN RAISE EXCEPTION 'Existing workspace tool not found'; END IF;
  start_pos := strpos(fn, ' elsif tool=''pull'' then');
  end_pos := strpos(fn, ' elsif tool=''products'' then');
  IF start_pos=0 OR end_pos<=start_pos THEN
    RAISE EXCEPTION 'Unexpected workspace pull route, no changes applied';
  END IF;
  old_fragment := substr(fn,start_pos,end_pos-start_pos);
  IF strpos(old_fragment, 'FOR UPDATE SKIP LOCKED')=0 AND strpos(old_fragment,'for update skip locked')=0 THEN
    RAISE EXCEPTION 'Legacy pull branch differs from reviewed version';
  END IF;
  EXECUTE substr(fn,1,start_pos-1) ||
    ' elsif tool=''pull'' then raise exception ''Use the controlled Take More Orders action.'' using errcode=''42501'';' ||
    substr(fn,end_pos);
END $old_pull$;
