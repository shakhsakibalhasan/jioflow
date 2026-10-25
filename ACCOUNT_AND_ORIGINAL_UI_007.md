# JioFlow update 007: original views + live Creator account management

## Installation
1. In Supabase SQL Editor, run ONLY supabase/migrations/005_account_management.sql once. Migrations 001–004 must already be applied. Do not rerun them.
2. Run VERIFY_005_ACCOUNT_MANAGEMENT.sql. It should show the new schema version, two true RPC checks and session_gate_present=true for all nine helper functions.
3. Extract JioFlow-Original-UI-Accounts-007.zip and upload all extracted files into the existing GitHub repository, replacing matching paths. Keep the folder structure.
4. Wait for Vercel deployment to finish. Hard refresh the main site and sign in with the existing Supabase account. Environment variables remain unchanged.

## Live account actions
Creator can edit an Owner/Admin/Agent name and phone, remove the account, or revoke existing JioFlow sessions. Creator cannot remove/edit their own Creator identity through these controls. Owner/Admin/Agent cannot invoke these Creator-only functions even by forging a request.

Remove is a soft removal: account access is disabled, shop ownership is detached, memberships are marked removed, and customer assignments/permanent-client ownership are cleared. Orders, customers, follow-up history and authorship remain. Physical Auth users are not deleted; the email remains reserved for history.

Force Logout revokes access to JioFlow data for every existing Supabase session for the target. All authorization helpers check the session ID, so refreshing an old token cannot restore access. It does not sign the person out of Google/Gmail or other apps. The interface checks at 30-second intervals and on focus; backend data access is denied immediately. The person can sign in again with their password, creating a fresh session.

Email/password changes, role reassignment, fine-grained permissions editing, and image upload are not added by this update. Email reset/invitations still depend on email delivery setup.

## Original interface
The retained original view implementations are reused in an isolated scope, without their browser-local authentication/bootstrap or browser writes. The main page keeps live Supabase login. It does not restore old sample records or local passwords.

Restored views include the shop dashboard, products, customers/follow-ups, permanent clients, orders, new order form, import form, couriers, profit, Agent reports, users/groups, workspace settings, profile and shop overview. Generic placeholder pages are replaced by retained layouts and controls. Read filters, tabs, pagination and CSV export work on loaded records. Live product edits/activation, customer edits, follow-up entry and history remain connected through their existing RPCs.

IMPORTANT: This does not complete every backend feature. Orders/imports/courier booking, real financial calculations, group/settings/permission editing and layout persistence remain unfinished. Their forms are restored as read-only previews or unavailable controls. Detail/report screens load recent records (up to 50 orders/customers/products), not a full report across hundreds of thousands of rows. Partial-data totals are labelled. Settings preview values are defaults, not saved backend settings. Agent approval/device enforcement still gates Agent workspaces.

## Validation
Local PostgreSQL-compatible tests execute migrations 001–005 and test hierarchy, tenant boundaries, session revocation, fresh login, removal/unassignment, history preservation and private audits. DOM tests cover 16 original views, live login/scope switching, account confirmation/RPC actions, and existing operational forms. Browser visual review uses isolated layout fixtures. No real account was edited/removed/logged out by the assistant; the remote migration must be applied by the project owner.
