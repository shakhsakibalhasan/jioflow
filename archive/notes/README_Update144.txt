JioFlow Update 144 — Separate imported and Agent statuses
Includes status fixes from 142/143; apply on the existing Update139–141 setup.

INSTALL
1. Run Database144.sql. This includes the corrected SQL143; do not run Database142.sql. Safe to run twice.
2. Replace all FOUR app files: custom-statuses.mjs, followup-status.mjs, record-panel.mjs, workspace-design.css.
3. Redeploy, then Ctrl+Shift+R in every open panel.

BEHAVIOR
Latest status in the Follow-ups table reads the latest imported order history, separately from native orders and Agent follow-up status. Agent updates never write that imported status. If no imported history exists, the existing native order status is used; blank imported status displays a dash.
Agent status shows the saved follow-up choice; Positive / Intermediate / Negative / Irregular appears directly below that Agent status. Not Connected shows below the Agent status when applicable and does not retain an older positive classification.
The imported capsule no longer inherits the Agent status color. Progressive fast/full hydration refreshes both status cells consistently.
No historical import values (including CANCEL), order history, or Order ID/phone conflicts are rewritten by this update.

VALIDATION
Local real database tests passed: migration twice, Owner/Agent full and fast projections, imported Returned remains unchanged while Agent switches Refuse/Confirm, independent Irregular response, original history details unchanged. DOM checks passed for all response labels and all-role shared renderer; prior settings/dropdown tests and 49-file deployment module graph passed. Live deployment and browser visual QA have not been performed.
