JioFlow Update177 — Legacy uploaded Never Assigned data

Requires Update176 and its prerequisites.
INSTALL: Run Database177.sql in Supabase SQL Editor, then refresh Follow-ups and select Never Assigned. No app files need replacement. The existing default on entering Follow-ups / applying filters remains Never Assigned.

This establishes the user-confirmed initial baseline for older uploaded customers: currently unassigned rows with no ever-assigned flag, no Unassigned reason and no recorded non-null assignment are classified as Never Assigned. Existing assignment flags, reason tags and recorded assignment history are retained. Previously assigned/unassigned rows do not re-enter Never Assigned.

List and count use the same existing predicate, now with corrected legacy flags. Existing search/date/security restrictions still apply. The screenshot count is not hardcoded; the result depends on actual assignment evidence and active filters.

Runs in one transaction with a short customer-table write lock while repairing flags and restoring the existing protective trigger. A failure rolls back the whole transaction. Re-running is supported. No customer, order or follow-up is deleted; no historical timestamp is invented. Old assignment events that were never recorded cannot be recovered; this baseline follows your confirmation about the uploaded data.

Local tests passed: applying the migration twice; legacy unassigned rows counted and listed; recorded former assignments and reason-tagged rows excluded; fast/full list consistency; date/search filters; Agent and anonymous access checks. Not run on production.
