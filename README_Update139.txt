JioFlow Update 139 — Completed follow-up and Pending counts

Apply Database139.sql in Supabase SQL Editor, then hard-refresh JioFlow.
No application code replacement is needed. Update 138 import remains unchanged.

Saved follow-up interactions (positive, negative, intermediate, irregular,
connected or not connected) now count as Completed and leave Pending.
The original workflow label and its matching section remain intact.
Confirmed customer section continues to show Confirm, not every completed call.
Owner/Admin/Agent summary counters and Agent Report use the same completion rule.
Processing remains an unattempted pending follow-up. Scheduled callbacks keep
working and their callback time remains available after the interaction is done.
Existing saved interactions are counted using the new rule immediately; orders,
courier status and historical imported delivery statuses are not rewritten.

Diagnose_Import_Status139.sql is optional and READ ONLY. Run it separately to
compare the screenshot customers' saved status, original CSV status columns and
newest native order. Share its results to identify why CANCEL is shown instead
of Returned. It does not replace any status blindly.

Local PGlite tests cover repeated migration, role-scoped full/fast list filters,
Completed/Pending/Confirmed separation, correct workflow/call buckets, dashboard
and Agent Report totals against independent SQL, Processing reset, callbacks,
and denial of foreign-shop updates. Live SQL has not been run by the assistant.
