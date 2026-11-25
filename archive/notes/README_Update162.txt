JioFlow Update162 — Confirm requires a saved order; appearance refinements

Prerequisites: Database155 and existing149/152/154 migrations installed; frontend through159. Includes appearance files from160/161, so160/161 do not need separate application.
1. Run Database162.sql in Supabase SQL Editor.
2. Replace the eight application files from this ZIP, including online-orders.mjs.
3. Deploy and hard refresh.

Confirm workflow:
Select the configured Confirm-kind status. Select Connected / Not Connected; Connected additionally requires Positive / Negative / Intermediate / Irregular. Update status remains disabled for Confirm. Create Order / New Order transfers the unsaved classifications and status note to the order form, without saving Confirm early. Save Order or Confirm & Book saves order and Confirm/classification/note in one database transaction. Failure rolls back both. Courier booking runs afterwards: if booking fails the saved order stays Confirm, but Booked does not increment. Retry with same request does not repeat the status action. An active Confirm-kind setting is required (including permanent customer status definitions when applicable).

Other statuses retain their normal Update status flow. Imported Latest status remains untouched. Completed semantics from155 remain. Orders Created dashboard/report box removed; Confirmed Customers renamed Confirm; Profit before Revenue. Native order records are retained.

Existing status-only Confirm records WITHOUT an active non-draft native order are backed up in private confirm_legacy_backup162 and returned to an active Processing-kind label. Historical events, imported statuses and order data are not deleted. This makes Confirm counts follow the new rule. Existing customers with qualifying saved orders retain their status.

Appearance:
Includes160/161. Sidebar selected item uses brand color. Light mode uses its original theme rules; dark styles are scoped to dark. Status/form colors now react to switching modes instead of retaining a prior mode's inline colors. Light list row hover adds a subtle brand tint. Custom picker persists across modes/reload. Revenue black, Profit regular.

Validation: cumulative database72–155 regression +162 twice, standalone Confirm rejection, atomic order and chosen negative response, missing response rejection, request replay, Not Connected handling. Four-role order form checks, Confirm UI gating/no premature mutation, dashboard order/removal, appearance persistence and49-file static build passed. No live database migration/deployment or browser visual verification performed.
