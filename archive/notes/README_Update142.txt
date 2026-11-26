JioFlow Update 142 — Shared follow-up statuses
Apply after Updates 139–141.

1. Run Database142.sql in Supabase SQL Editor. It is transactional and safe to run twice.
2. Replace these three files in the deployed project root:
   custom-statuses.mjs
   followup-status.mjs
   record-panel.mjs
3. Redeploy and hard refresh open panels.

Workspace Settings is the shared source for active follow-up tabs and update choices across Creator, Owner, Admin and Agent panels. Permanent Customer continues using its own configured status list. Add/rename/color/remove changes apply when the relevant view is opened/refreshed. Existing history is retained when a status is removed. Existing customers follow a renamed status via the settings migration already installed.

No Answer and other configured labels are validated against active definitions, replacing the legacy fixed whitelist while retaining the installed authorization guard. Exact-label tabs have separate filter/count keys, so names like Pending or Busy cannot collide with aggregate or call outcome filters. Saved interactions count Completed and leave Pending through Update139. Processing still resets an interaction to Pending. Confirm and callback behaviors remain tied to status configuration. Confirm reporting supports renamed Confirm labels.

Settings status rows no longer show category text beside the colored capsule.

Local validation passed: cumulative SQL including running 142 twice; real No Answer save; Owner/Agent full and fast lists/counts; Pending removal; rename migration; removed status rejection; renamed Confirm aggregate; all-role DOM dropdown/tab/save checks; existing status control regression; 49-file deployment module graph.
Live deployment and browser visual verification were not performed. No historical delivery status or Order ID/phone conflict data is changed by this patch.
