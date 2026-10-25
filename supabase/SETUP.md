# JioFlow backend setup — phase 1

Project API URL: https://xxsiwglshmqfqvbvxytw.supabase.co

1. Open this project in Supabase Dashboard → SQL Editor → New query.
2. Paste migrations/001_identity_and_shops.sql and Run once.
3. Report the success message or exact SQL error. Do not run against a project
   with existing jf_* tables without reviewing their schema first.
4. Create the initial Creator identity through Supabase Authentication using
   the intended email. Its database role must be assigned in a separate trusted
   setup step; never use public first-visitor signup to select the Creator.

This migration only creates identity/shop tables and read policies. The browser
CRM is still a local demo. Remote login, account provisioning, operational tables,
transactional write endpoints, sessions/device approval, uploads and data migration
are NOT connected by running this SQL. Existing browser passwords/accounts are
not silently migrated. The first live Creator uses an Auth setup/reset flow.

All role/permission writes are denied to client keys. A singleton index protects
Creator identity, one Owner can own only one shop, and read policies scope access.
Agent operational access will require approved-device session enforcement before
customer/order tables are exposed. No CRM customer/order data is exposed here.

The publishable key supplied in conversation is frontend configuration. Keep
Supabase secrets/service_role keys only in the deployment secret store. Never
put browser backups, passwords, sessions or secret keys into GitHub.

## Online login test page

After 001 is executed and the trusted Creator profile is inserted, deploy
online.html, online.js, online-client.mjs, online.css and updated build.mjs.
Visit /online.html. Use the password set in Supabase Authentication, not the
old browser-demo password unless you deliberately set the same password.
This is a staged online account viewer; it does not enable CRM writes or import
browser data. Agents cannot enter this portal until their device access flow is
implemented. Owners/Admins see only rows allowed by PostgreSQL policies.
The existing /index.html remains the browser demo during this migration.

Sessions are per browser tab session, contain Supabase tokens (not passwords),
and refresh using the Auth API. Login also reads the server profile; missing,
inactive or removed profiles are rejected. Run node tests-online.mjs for mocked
Auth/API tests. A real cross-device login still needs user verification.
