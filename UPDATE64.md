# Update 64 — Supervisor workspace access

Requires Update 63 application files and database migrations through 044.

1. Run Database64.sql in Supabase SQL Editor.
2. Replace agent-workspace.mjs, online.js and workspace-design.mjs at repository root and commit to Vercel.

Creator can open active Owner/Admin/Agent workspaces across permitted businesses. Owner can open Admin/Agent workspaces in the Owner's own business. Admin can open Agent workspaces only with Manage users & groups (users) permission in that same business. Admin cannot open Owner/Admin peers. Agents receive no inspection permission. Paused/inactive/deleted targets and mismatched businesses are rejected by the server.

Use View Dashboard in Owners/Admins/Agents/Account Access. The selected business is retained and a banner identifies the viewed person. Back to my workspace ends inspection. Owner/Admin views show the business workspace; Agent views retain assigned-customer/order scope. There is no password sharing or impersonation: actions use the signed-in supervisor's existing permissions and audit identity. Viewing does not grant any missing action/finance permission. It is a supervisor view of application pages, not a remote screen recording or access to another user's private login session/notifications.

Includes the email sync fix previously supplied in chat: pending_email uses an empty string when no change is pending, preserving the existing NOT NULL constraint. No automatic email confirmation or security bypass.

Validated locally: database suite through 045, Creator/Owner role context, Admin hierarchy/other-business denial, email sync, directory controls, Agent client scope, account actions and production build. Production SQL/deployment has not been changed by this package.
