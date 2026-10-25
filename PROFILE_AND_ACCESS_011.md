# JioFlow update 011 — Creator profile and account editing

## Install on the main Vercel site
1. Migrations 001–007 must already be applied. Run only 008_creator_profile_edit.sql once in Supabase SQL Editor. If 006 or 007 is missing, apply the missing migration first; never rerun an applied migration.
2. Extract this ZIP and upload its contents to the existing GitHub repository root, replacing matching paths. Keep all other files/assets. This package includes api/manage.mjs and server/account-service.mjs, which must retain their folder paths.
3. Wait for Vercel Ready. Refresh the main URL and open My Profile. Existing server environment variables remain unchanged.

## Creator own profile
Edit my profile saves name, phone, job title, address, user code and PNG/JPEG/WebP profile image (up to 250 KB). Email changes use provider confirmation. The Creator cannot demote, reassign, deactivate or remove their own Creator identity using account controls.

Change password asks Current password, New password and Confirm new password, with Show passwords. The current password is reauthenticated against the same live Auth user before the update. A new password requires 12–128 characters. Plaintext passwords are not persisted. Current password is required; an unknown password requires the email recovery flow.

## Creator edits other accounts
Edit name, email, phone, title, address, code, photo, assigned business, Owner/Admin/Agent role and boolean permissions. A role/shop/permission change requires confirmation, revokes existing JioFlow sessions and retains old order authorship/history. Moving shops or changing roles clears old customer/permanent ownership and group links. A shop can have one Owner. Reassigning to an occupied Owner position is rejected atomically. Agents cannot receive administrative or finance permissions. Agent workspace/device approval remains separate and is not implemented by this release.

Passwords of others are never displayed or directly overwritten. Reset password resolves the recipient from the authorized account ID on the server, then requests a reset email. For an unverified invited account, it requests the invitation/setup email instead.

## Email verification
New invited account: invitation email → click link → set own password → sign in. Send verification resends the invitation for pending accounts.
Other-account email change: Creator saves new email → provider-managed change is prepared, but login email stays unchanged → wait at least one minute → Send verification → recipient confirms the new and (depending on secure-change settings) current inbox → the existing user ID/profile synchronizes to the confirmed email. Generated links/tokens stay server-only and are never returned to the Creator. Own-profile email change uses the ordinary authenticated provider confirmation flow.

SMTP/email delivery setup is deliberately left for last, per request. Provider restrictions, send limits and SMTP configuration can prevent delivery. This release does not claim emails were delivered.

## Other-device login
Creator has no device restriction. Every device signs into the same live Auth account with its current email/password. Local demo credentials are not migrated automatically. Login now distinguishes credential rejection and unconfirmed email. Auth/session tests use two independent browser storage instances. No real cross-device login with the user's credentials was performed, so an actual credential-specific error still needs the exact error screenshot (never the password).

## Validation and scope
Local database tests execute migrations 001–008 and verify Creator/self profile edits, tenant-safe role transitions, private audit records, same-shop Owner collision rollback, permission restrictions, historical memberships, email sync and existing account/order behavior. UI/Auth/server tests cover protected self role, current-password verification, no stored plaintext, target-email-only reset, provider failures and token non-disclosure. Browser QA uses synthetic profile values and does not send emails or modify production accounts.

The Sites preview is separate from the main Vercel deployment. Uploading this package is required to update the main site. Remaining courier/import/report/settings features are not completed by this release.
