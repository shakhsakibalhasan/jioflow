# JioFlow — Products, Customers and Follow-ups (004)

SMTP is deferred. This update requires no sending domain and sends no emails.
It uses the existing verified Supabase Creator login; it does not enable unverified logins.

## Install

1. Run `supabase/migrations/004_products_customers_followups.sql` ONCE in a new Supabase SQL Editor query, after 003 has succeeded. This adds functions/indexes, not sample data. Do not rerun older migrations.
2. Run `supabase/VERIFY_004.sql`. Expect version 004 and all four boolean checks true. An error must be reported instead of deleting tables.
3. Extract this ZIP; upload the contained files/folders into the root of the existing GitHub repository, replacing existing filenames. Preserve the `supabase` directory. Commit; wait for Vercel Ready. Uploading a ZIP alone does not install it.
4. Open https://jio-flow.vercel.app/online.html . Sign in with the actual Supabase Creator account. Choose a business. The old browser CRM at `/` is still separate.
5. If the online shop list is empty, create a business through Create Shop. That requires the previously supplied Vercel account backend and environment variables, but does not send email. The old local Ecory shop is not auto-imported. Prefer an explicitly named test business until the migration of real data is ready.

## Verify without SMTP

- Products: add a test product, refresh, edit its price, deactivate/reactivate it. Creator/Owner can enter cost. Admin needs products permission; entering/viewing cost additionally requires profit permission. No images/files are uploaded in this update.
- Customers: add a test name and Bangladeshi phone, refresh, then submit the same number with +880 prefix. It should update the same customer rather than create a second profile. This update accepts valid Bangladeshi mobiles or international numbers beginning with +.
- Follow-ups: record Busy with Callback and a local date/time plus a note. Open Notes & history. Then mark Completed and verify callback clears while earlier notes remain.
- Filter by phone prefix and follow-up status. Lists load up to 50 records with next/previous navigation; these are page counts, not overall dashboard totals.
- Only already-active Agent memberships can be assigned. Pending Agents are not selectable. Permanent client requires an assigned Agent. Because device approval is not implemented, this update does not activate Agents or expose operational records to them.

## Access and data behavior

Operational writes run inside database functions with server-side role/shop/permission checks, not through unrestricted table grants. Shop-scoped foreign keys and assignment checks prevent cross-business links. User roles supplied from the browser do not grant access. Customer save also creates one current follow-up; repeated saves preserve the existing follow-up and event history. Recording a follow-up appends an event and saves a non-empty note atomically.

The existing database privileges still block anonymous access and direct client table mutations. The new authenticated RPCs are the explicitly allowed, permission-checked write interface. Products can be made inactive, not hard-deleted. Customer import and old browser data are not migrated by this SQL.

No email invitations, password resets, courier bookings, orders, CSV batches, group distribution jobs, logo/photo uploads or Agent approval/session enforcement are enabled by this update. Account backend from 003 remains in place and SMTP can be configured later.

## Checks performed

The full migration chain was executed against a local in-memory PostgreSQL-compatible database. Tests cover permissions, price validation, product activation, hidden costs, normalized duplicate phones, one current follow-up, callback validation, notes/history, filtered pages, tenant isolation and blocked Agent/anonymous access. UI rendering is checked with mock data. These tests do not execute SQL or insert records in your live Supabase project. Confirm the live workflow with the small test records above after installation.
