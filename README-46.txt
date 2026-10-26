Update 46 — apply after Update 44. Includes Update 45 ash panel styles.
1. Supabase SQL Editor: run Database46.sql (requires migration 030 from Database43.sql).
2. Upload ALL files to their existing paths in GitHub. Include server/account-service.mjs, password-reset.mjs and build.mjs. The server folder is required for /api/manage.
3. Wait for Vercel deployment, then open https://www.jioflowbd.com/ and hard refresh.
No new environment variables are needed if the existing account service works. Existing SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, SUPABASE_SECRET_KEY and JIOFLOW_APP_ORIGIN are still required on Vercel. Never put the secret key in frontend code.

FLOW
Agent: My Profile -> Request password reset -> submit.
Authorized Creator/Owner/Admin: Notifications -> Reset password -> New password + Confirm password -> Save password.
Account Access: Reset password opens the SAME new/confirm password form. No email reset link is sent by this form.
Minimum 6, maximum 128 characters, matching fields, Show/Hide passwords. Provider password-strength rules also apply.
Existing role hierarchy remains: Creator manages lower accounts; Owner manages their shop's Admins/Agents; Admin with Manage users permission manages their shop's Agents. No reset of one's own account or the Creator here. Creator/Owner/Admin self-change still uses the current-password form.
A successful server-side reset closes the request and revokes previous JioFlow sessions. Agent new-login approval remains required.
No plaintext password is stored in CRM data, audit logs or API responses. The server uses the existing privileged Auth API after database authorization.

CHECKED LOCALLY
Database through 031: hierarchy, tenant/self/Creator/anonymous denial, Agent request -> supervisor feed -> managed password -> request consumed -> session revocation, one-use operation and failure cleanup.
Server/UI tests: origin and role gates, mismatched passwords, privileged Auth update, no password response, shared forms and notification actions. Build passed.
Not deployed to your Vercel or production database. Live Auth password changes have NOT been performed.
Source: c2b98b0f709ccfe8cb1d746b0c1b4852b8f37fc8
