JioFlow update 012

Apply supabase/migrations/009_agent_sessions_shops.sql once in Supabase SQL Editor, after migrations 001–008. This migration does not configure Auth password policy or SMTP.

Upload this package's contents into the existing GitHub repository root and commit; allow the existing Vercel project to redeploy. Keep the existing server environment variables. Do not upload a ZIP file as the application's source. Do not put server credentials in frontend files.

New Agent accounts: email-format login address, Full name, unique Jio ID and password (minimum 6 characters). No invitation or email verification is sent for these managed Agents. Owner/Admin verification remains required. Existing unverified invitations are not automatically converted.

Agent login creates a request on Dashboard / Agents / Account Access. Creator, shop Owner or an Admin with user-management permission can approve/decline. The page checks every 10 seconds. Approval is bound to the Supabase Auth session. Refreshing a page/token preserves it; logout/new login needs new approval. A new approval revokes all other Agent sessions. Pending Agents cannot read operational data. Approved Agents can read/edit their own customer queue and orders according to permissions. They cannot see product cost or profit.

Login still uses email and password. Jio ID replaces the Agent phone field; it is not an alternative login identifier. For reliable email password recovery, use an inbox the account holder can access. A fictitious email cannot receive recovery links.

Supabase Auth settings: check that minimum password length is 6 if you want to allow six-character passwords. The app cannot override a stricter hosted Auth policy. Keep Owner/Admin email verification enabled. This update selectively provisions managed Agents through the server.

Creator controls: existing account edit, role/shop permissions, activation, logout and removal remain; own password requires current password, other users receive reset emails. Shops support edit, logo upload, Delete and Restore. Delete archives the business, blocks staff access and preserves historical records. Inside product/customer/follow-up/order sections, Creator record controls remove/restore records from active lists. Order archiving does not cancel courier bookings or rewrite accounting history. Product/customer editing and supported order status/note/assignment editing remain available. Arbitrary courier-aware financial edits and permanent history erasure are not implemented.

Deployment verification: create an Agent; verify there is no email invitation. Sign in as Agent in a second browser, confirm no operational rows are accessible before approval. Approve in the correct shop, verify only that Agent's work is visible. Logout/login, verify approval is requested again. Approve a different device, verify the old session loses access. Delete/restore a test shop and verify orders remain intact.

Validated locally with mocked Auth/API and an in-memory PostgreSQL-compatible database. No production SQL, accounts, credentials or email settings were changed by this package build. Courier integrations, full reporting, imports and settings connections remain separate unfinished work; this update does not claim the entire CRM is production-complete.
