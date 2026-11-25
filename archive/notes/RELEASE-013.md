JioFlow update 013

Apply migrations 001–009 first. Then run supabase/migrations/010_notifications_passwords.sql once, using the entire file through COMMIT. No production database changes have been made by this package build.

Upload the extracted package contents to the root of the existing GitHub repository, replacing matching files, commit and allow the connected Vercel project to redeploy. Existing server environment variables remain required. The ZIP is source code, not a file to leave unextracted in GitHub.

Changes:
- Removed the prominent development-status banners and technical preview notices from retained screens. Recent-record counts remain as compact scope labels; unavailable controls remain disabled.
- Creator, Owner and Admin can change their own password using Current password + New password + Confirm password. The provider rechecks current credentials; passwords are not stored locally.
- Agents have a Request password reset option. Requests appear in the dashboard Notifications bar. Creator, the shop Owner or an Admin with user-management permission can approve/decline. Approval lasts one hour and allows one password change. After approval, use Send reset email. A real accessible inbox and working email delivery are required for the email link.
- Migration 010 installs a narrowly scoped Auth password-update trigger. It rejects an Agent password hash change unless there is an approved, unexpired request, then consumes that approval. Creator/Owner/Admin changes are unaffected. Creating new Agent identities remains supported because initial Auth creation precedes Agent membership.
- Dashboard notification bar displays Agent login requests, password requests/decisions, new orders/order status changes and business creation. Notifications are scoped to the selected business and server permissions; read state is per user. It checks for updates every 10 seconds, with up to 50 recent notifications displayed. Existing login approval and single-session enforcement remain unchanged.
- Only Creator can create multiple shops. The shared Create/Edit Shop form groups business name/category/logo, email/phone/address/district, website/Facebook page and BDT/Asia-Dhaka workspace defaults. Name, valid email, contact number and address are required. Each shop uses the same CRM screens with separate records and access. Create the shop first, then assign its Owner through Account Access. Existing shop edit/delete/restore remains.

Local validation includes full migration execution and permission checks using in-memory PostgreSQL, mocked Auth/API tests, notification/reset/business form checks, existing workflow regression tests and browser review with synthetic records. No real passwords, reset emails, user logins or production accounts were changed during validation.

Limitations retained: full courier booking/status synchronization, full-dataset reporting, import processing, group distribution and settings persistence remain unfinished. Removing interface development notices does not complete those integrations. Email delivery has not been configured as part of this update.
