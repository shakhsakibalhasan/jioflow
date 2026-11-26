-- JioFlow: activity for unassigned customer cards. No historical customer rows are changed.
CREATE TABLE IF NOT EXISTS jioflow_private.jf_unassigned_activity (
  shop_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  actor_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('Viewed','Edited')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (shop_id, customer_id)
);
ALTER TABLE jioflow_private.jf_unassigned_activity ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON jioflow_private.jf_unassigned_activity FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION jioflow_private.jf_capture_unassigned_activity()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE uid uuid := auth.uid();
BEGIN
  IF uid IS NULL OR NOT jioflow_private.reads_staff_operations(NEW.shop_id) THEN RETURN NEW; END IF;
  IF TG_TABLE_NAME='jf_customers' THEN
    IF NEW.assigned_membership_id IS NOT NULL THEN RETURN NEW; END IF;
    IF TG_OP='UPDATE' THEN
      IF (NEW.full_name,NEW.phone,NEW.email,NEW.address,NEW.district,NEW.area,NEW.source,
      NEW.workflow_label,NEW.unassignment_tag,NEW.assigned_membership_id,NEW.permanent)
      IS NOT DISTINCT FROM
      (OLD.full_name,OLD.phone,OLD.email,OLD.address,OLD.district,OLD.area,OLD.source,
      OLD.workflow_label,OLD.unassignment_tag,OLD.assigned_membership_id,OLD.permanent)
      THEN RETURN NEW; END IF;
    END IF;
  ELSIF TG_TABLE_NAME='jf_followups' THEN
    IF NOT EXISTS (SELECT 1 FROM public.jf_customers c WHERE c.shop_id=NEW.shop_id AND c.id=NEW.customer_id
       AND c.assigned_membership_id IS NULL AND c.archived_at IS NULL) THEN RETURN NEW; END IF;
    IF TG_OP='UPDATE' THEN
      IF (NEW.status,NEW.call_outcome,NEW.callback_at,NEW.last_contact_at,
       NEW.call_status130,NEW.customer_status130)
       IS NOT DISTINCT FROM (OLD.status,OLD.call_outcome,OLD.callback_at,OLD.last_contact_at,
       OLD.call_status130,OLD.customer_status130)
      THEN RETURN NEW; END IF;
    END IF;
  ELSIF TG_TABLE_NAME='jf_notes' THEN
    IF NEW.customer_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.jf_customers c WHERE c.shop_id=NEW.shop_id
       AND c.id=NEW.customer_id AND c.assigned_membership_id IS NULL AND c.archived_at IS NULL) THEN RETURN NEW; END IF;
  ELSE RETURN NEW; END IF;
  INSERT INTO jioflow_private.jf_unassigned_activity(shop_id,customer_id,actor_id,action,occurred_at)
  VALUES(NEW.shop_id,CASE WHEN TG_TABLE_NAME='jf_customers' THEN NEW.id ELSE NEW.customer_id END,uid,'Edited',clock_timestamp())
  ON CONFLICT (shop_id,customer_id) DO UPDATE SET actor_id=EXCLUDED.actor_id,
    action=EXCLUDED.action,occurred_at=EXCLUDED.occurred_at;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION jioflow_private.jf_capture_unassigned_activity() FROM PUBLIC;

DROP TRIGGER IF EXISTS jf_unassigned_customer_audit ON public.jf_customers;
CREATE TRIGGER jf_unassigned_customer_audit AFTER UPDATE ON public.jf_customers
FOR EACH ROW EXECUTE FUNCTION jioflow_private.jf_capture_unassigned_activity();
DROP TRIGGER IF EXISTS jf_unassigned_followup_audit ON public.jf_followups;
CREATE TRIGGER jf_unassigned_followup_audit AFTER INSERT OR UPDATE ON public.jf_followups
FOR EACH ROW EXECUTE FUNCTION jioflow_private.jf_capture_unassigned_activity();
DROP TRIGGER IF EXISTS jf_unassigned_note_audit ON public.jf_notes;
CREATE TRIGGER jf_unassigned_note_audit AFTER INSERT ON public.jf_notes
FOR EACH ROW EXECUTE FUNCTION jioflow_private.jf_capture_unassigned_activity();

CREATE OR REPLACE FUNCTION public.jf_unassigned_activity(target_shop uuid,target_customer uuid,record_view boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE activity jsonb;
BEGIN
  IF NOT coalesce(jioflow_private.reads_staff_operations(target_shop),false) THEN
    RAISE EXCEPTION 'Staff access required.' USING errcode='42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.jf_customers WHERE id=target_customer AND shop_id=target_shop
                 AND assigned_membership_id IS NULL AND archived_at IS NULL) THEN
    RETURN NULL;
  END IF;
  IF record_view THEN
    INSERT INTO jioflow_private.jf_unassigned_activity(shop_id,customer_id,actor_id,action,occurred_at)
    VALUES(target_shop,target_customer,auth.uid(),'Viewed',clock_timestamp())
    ON CONFLICT (shop_id,customer_id) DO UPDATE SET actor_id=EXCLUDED.actor_id,
      action=EXCLUDED.action,occurred_at=EXCLUDED.occurred_at;
  END IF;
  SELECT jsonb_build_object('name',coalesce(nullif(trim(p.full_name),''),'Staff member'),
    'action',a.action,'at',a.occurred_at)
  INTO activity
  FROM jioflow_private.jf_unassigned_activity a
  LEFT JOIN public.jf_profiles p ON p.id=a.actor_id
  WHERE a.shop_id=target_shop AND a.customer_id=target_customer;
  RETURN activity;
END $$;
REVOKE ALL ON FUNCTION public.jf_unassigned_activity(uuid,uuid,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.jf_unassigned_activity(uuid,uuid,boolean) TO authenticated;
