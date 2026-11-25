# JioFlow — Account Backend Update (003)

## What this update enables

On `/online.html`: verified email/password login, create shop, invite Owner/Admin/Agent with a business selected, an optional initial password, account lists with email/pending status, and email-based password reset/set-password. Invitations send actual emails once Supabase SMTP is configured. Passwords go only to Supabase Auth, never to CRM tables.

Rules are checked inside PostgreSQL, independently of hidden buttons:
- Only the verified Creator creates shops or assigns their Owner.
- A verified Owner creates Admins/Agents only in their own shop.
- A verified active Admin creates Agents only if explicitly granted `users` permission.
- A shop has one Owner. A user is not silently reassigned from another shop.
- Pending Agents have no customer/order access. Device approval and the Agent operational workspace are not implemented in this release.
- No public Create Account screen. Signup metadata never assigns roles.

## 1. Supabase migration

Your 001 and 002 migrations have already been applied. Run only `supabase/migrations/003_account_provisioning.sql` once in a new SQL Editor query in project `xxsiwglshmqfqvbvxytw`. If it errors, stop and report the exact error. Do not rerun 001/002 or delete tables.

Then run `supabase/VERIFY_003.sql`. Expect version 003 to be present, all RLS checks true, no anonymous RPC access, and no direct authenticated table-write grants.

## 2. Supabase email configuration

In Authentication → URL Configuration:
- Site URL: `https://jio-flow.vercel.app`
- Additional allowed Redirect URL: `https://jio-flow.vercel.app/online.html`

Use the standard Supabase Invite User and Reset Password email templates with `{{ .ConfirmationURL }}` links. This release accepts the standard implicit-flow invite/recovery callback and immediately removes tokens from the address bar. Custom templates using token_hash/code callbacks need a separate implementation and should not be substituted here.

In Authentication → Email/SMTP settings, configure your own SMTP provider for delivery to non-team recipients. Supabase's default sender restricts recipients to project team addresses; having the SQL and API deployed alone will not remove that restriction. Use a verified sender address from your SMTP provider. Keep Confirm Email enabled and disable public signup if your project settings permit admin invitations with signup disabled. No public signup action is used by this application.

## 3. Vercel server settings (not GitHub)

Open Jio-Flow → Settings → Environment Variables. Add these to **Production**. Keep the secret value hidden and never paste it in chat or commit it to the repository.

| Name | Value |
| --- | --- |
| `SUPABASE_URL` | `https://xxsiwglshmqfqvbvxytw.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | The existing project's `sb_publishable_...` key |
| `SUPABASE_SECRET_KEY` | A server `sb_secret_...` key from Supabase project Settings → API Keys |
| `JIOFLOW_APP_ORIGIN` | `https://jio-flow.vercel.app` (no trailing slash) |

A legacy service_role JWT can alternatively be set as `SUPABASE_SERVICE_ROLE_KEY`; the new secret key is preferred. Do not set a secret with a `VITE_`, `NEXT_PUBLIC_` or other client-public prefix. Modern secret keys are sent only in the `apikey` header; a signed-in user's JWT is used for caller-relative database RPC authorization.

Preview deployments are intentionally not allowed to send production account invitations under their preview origin. Use the canonical production domain or explicitly configure a separate isolated test project/origin.

## 4. GitHub upload and deploy

Extract this ZIP and upload its files to the ROOT of `jioflowbd-coder/Jio-Flow`, preserving the `api/`, `server/` and `supabase/` folders. Do not upload the ZIP itself. Existing filenames should be replaced. Commit, then wait for the Vercel production deployment to become Ready. If environment variables were added after deployment, Redeploy.

Vercel uses the existing build (`npm run build`, output `dist`) plus the root `api/manage.mjs` Node function. The `server/` directory is imported by that function and must also be uploaded. It must never be copied into `dist`.

The ChatGPT-hosted static preview can show the UI; this Vercel Node API does not run on that static host. Actual invitations and provisioning are tested on your configured Vercel deployment.

## 5. Verify the real workflow

1. Open `https://jio-flow.vercel.app/online.html` and sign in using the actual Supabase Creator account. Browser-demo passwords/accounts are separate.
2. Create one business. Then Add Account → select that business → Owner → enter name/email/phone. Set an optional initial password (12–128 characters), or let the recipient choose a password through their invite email.
3. The recipient opens the emailed link, sets a password and signs in. Mailbox verification is required; it is not simulated.
4. Owner invites an Admin into the same business. Verify Admin cannot create an Owner or a shop, and cannot act in another shop.
5. An invited Agent appears as pending. They must not see operational records until device/session approval is implemented.
6. Use Forgot Password and follow the emailed link. Password forms include show/hide and confirmation. No real test emails or account changes were sent by the assistant.

If an invitation is sent but attaching the CRM identity fails (for example, the Owner assignment changes concurrently), the Auth identity may remain unassigned. It cannot read operational data. Do not delete/reassign existing users blindly; inspect the account request and Auth user to recover deliberately. This update does not silently transfer existing Auth identities or browser-demo accounts.

## Still unfinished

Full CRM operational writes, browser-data migration, photo/logo upload, user edits/removal/force logout, Agent device sessions/approval, bulk CSV import and real courier adapters are not enabled by this update. The original `/` remains the existing browser CRM while `/online.html` is the staged online account setup. Do not use real business orders until the operational backend and migration are complete.

## Validation

- API tests use mocked Auth/REST responses and cover denial before mail delivery, invalid role/origin, inactive/unverified accounts, no leaked keys, mail failure and initial-password fallback.
- A local in-memory PostgreSQL-compatible database executed 001, 002 and 003 and checked role hierarchy, tenant foreign keys, profile visibility, finance restrictions and blocked Agent/anonymous access.
- Login/recovery dialog was inspected in the browser; no real credentials were entered and no email was sent.
- SQL execution, email delivery, actual Vercel function deployment and cross-device account login still require the configuration and checks above.

Official references:
- https://supabase.com/docs/guides/auth/users
- https://supabase.com/docs/guides/auth/auth-smtp
- https://supabase.com/docs/guides/getting-started/api-keys
- https://vercel.com/docs/functions/runtimes/node-js
