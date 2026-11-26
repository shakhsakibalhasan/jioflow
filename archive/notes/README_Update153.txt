JioFlow Update153 - Bulk Unassign with workspace reasons

Install after your current updates (Update152 recommended):
1. Run Database153.sql in Supabase SQL Editor once.
2. Replace these FOUR files in GitHub and deploy:
   assignment-picker.mjs
   record-panel.mjs
   workspace-tools.mjs
   online-client.mjs
3. Hard refresh the site once.

Assigned customer selection now shows Bulk Unassign in the selection toolbar.
Customer/Follow-up/Permanent Customer record panels use the same action. The existing workspace Unassign selected action opens the same popup.
- Compact 440px maximum popup with selected count, explanation, optional Reason tag, Cancel and Unassign.
- Reads latest active Unassign Tags from Workspace Settings each time the popup opens. Inactive/removed tags are omitted; No reason is available.
- Confirm clears customer assignment and stores the reason. Order records, order statuses, follow-up status/responses, notes and history remain unchanged. Permanent flag remains unchanged.
- Existing unassigned customers are left unchanged. Selected ids from other businesses or unavailable/archived records cause an atomic rejection.
- Creator/Owner/Admin staff with assignment permission can use it. Agents cannot bulk-unassign.
- Maximum 10,000 customers per action. Unassign batches are updated with one set-based query.
- Successful save clears selection and refreshes the current list/counts through the existing reload flow.

Local validation: popup/tag escaping and loading, role/selection visibility, exact payload, active-tag validation, no-reason path, repeated action, unavailable-id rollback, status/details preservation and foreign-shop/Agent denial passed. Migration applied twice safely. Existing shared client/search/performance checks and release build passed.
Not applied to your live site/database; no real-browser visual test performed.
