JioFlow update 014

Apply migrations through 010 first, then run supabase/migrations/011_shop_pause_delete.sql once. Upload this package's extracted files to the existing GitHub repository root, replace matching files, commit, and wait for the connected Vercel deployment.

Notifications now use one bell icon beside the account in the top-right header on workspace pages. The unread badge remains. Clicking opens a dropdown with notifications/actions and a close button. The wide dashboard notification bar has been removed.

Creator shop controls:
- Pause shop: optional reason, immediately blocks business operations for Owner/Admin/Agent through existing database permission checks, revokes their current sessions and preserves all shop data. A new login shows the paused-workspace screen. Other shops stay operational.
- Resume shop: restores the shop's availability. Previously revoked sessions require a fresh login; Agents still require their normal session approval.
- Delete shop: one Delete/Cancel confirmation, no typed business-name step. Permanently deletes the shop and its customer/product/order/follow-up/payment/shipment/group/import/notification records in one database transaction. This cannot be restored. Existing parcels booked with courier providers are not cancelled by database deletion. Retained user identities are made inactive; private access audit records remain. Only Creator can call pause/resume/delete RPCs.
- Older archived shops may still be restored, or permanently deleted with the new Delete action.

Validation: migrations 001–011 executed in local in-memory PostgreSQL; populated-shop permanent deletion including order finance, notes, groups, shipment events and notifications; Creator-only authorization; Owner/Admin/Agent denial while paused; resumed Agent access/approval; unaffected other businesses; UI checks for one confirmation and pause/resume labels; browser review with synthetic records. No real shop, account, password or production database has been changed during validation.

The source package includes the previous updates. Courier integration, full reporting/import/settings connections and email delivery setup are still separate work. This update does not complete those unfinished integrations.
