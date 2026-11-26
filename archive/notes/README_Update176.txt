JioFlow Update176 — Fixed Assigned options
Requires Update175 and its prerequisites.

INSTALL
1. Run Database176.sql in Supabase SQL Editor.
2. Replace custom-statuses.mjs (ONE file).
3. Deploy as usual and refresh once.

Assigned always begins with starred Processing, then starred Confirm. These are fixed options and have no Edit/Remove controls in Workspace Settings. Other Assigned tags remain configurable. The fixed Confirm option uses the existing Confirm-category status and existing order-backed confirmation rules.

Processing is an assigned customer with no saved/attempted follow-up since the latest recorded assignment. Saving a follow-up removes the customer from this fixed Processing option, even if the saved workflow label is Processing. Completed retains the saved Processing tag. Reassignment starts a new unworked period without deleting historical follow-ups. Legacy assignments without timestamps use existing saved interaction evidence rather than inventing dates.

Filtering and count badges use the same server predicate. Existing search/date/Agent permissions remain active. No history is deleted or reset.

Local checks passed: SQL installed twice; fast/full Processing results and counts; saved interaction exits Processing and enters Completed; fixed starred tabs survive an empty configured list; Settings cannot edit/remove fixed options; static build graph. Not installed or deployed on production.
