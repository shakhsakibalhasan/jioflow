# JioFlow workspace completion checkpoint — 022

This is a tested source checkpoint, not a claim that the production service is fully commissioned. The main Vercel site and production database were not modified in this session. No real courier orders or emails were sent.

## Implemented
- Durable, per-shop/per-account page layouts: rename, reorder, hide/remove sections, add/delete text widgets, density and reset. Agent layout editing stays blocked.
- Business delivery/workflow settings, custom labels/tags/sources, return preference and administrator-controlled Agent pull count/source rules.
- Real group CRUD and transactional distribution to an Agent/group, unassignment, select-all/selected rows, and approved Agent self-pull with `FOR UPDATE SKIP LOCKED`.
- Product bulk active/inactive/archive/restore, featured state, row archive, and CSV/XLSX SKU-based product import. Ecory catalog RPC is now allowed by the online client.
- Owner can manage Admin/Agent in their own shop; authorized Admin can manage Agent only. Contact/permission edits, activation/deactivation, removal, force logout and email-action authorization are server checked. Staff cannot move accounts between shops or alter Creator/Owner access.
- Full-database summary counts and matching paged customer/order explorer, preserving existing RLS. Order counts use the selected reporting window; customer figures are current snapshots. Order previous-period counts are queried when a finite period is selected.
- Database source totals/time chart, all-time Agent overview/detail records, top-performer sales/purchase-rate/profit summary and finance aggregates.
- Actual order cost/COD ledger editing; missing costs stay unknown. Finance includes product cost, courier charge, COD fee, packaging, returns and other costs. COD receivables use delivered orders and recorded receipts, not an external settlement feed.
- Customer profile order/history viewer. Assigned Agents can read limited order-history snapshots for their customer without gaining access to other Agents' courier records.
- Durable historical-order import staging and processing jobs, resumable after refresh once staging is complete. One phone can have many distinct invoice IDs. Re-uploaded invoice IDs update the same historical record; conflicting phones are rejected. Invalid rows are isolated and reported.
- CSV/XLSX selection/drop keeps a shared one-file lock between customer and history workflows. Historical imports preserve original product/status/amount/source/tracking text separately from new orders; they do not fabricate new confirmed sales or courier bookings.

## Still requires external information / production setup
1. Steadfast/Pathao merchant API documentation, merchant-approved API access and server configuration. Phone-history service name/documentation is also missing. Actual booking, provider cancellations, webhook/poll tracking and automated settlement feeds are not implemented or verified at this checkpoint. Existing booking controls stay unavailable.
2. Apply migrations 014–018 to the actual Supabase project after 013, then deploy this source to Vercel. `JioFlow-Database-022.sql` combines 014–018 in one transaction. Do not run it twice; numbered migrations remain in source.
3. Signed-in acceptance checks on the deployed app, courier sandbox/approved test booking, email recovery and a representative load test. Local tests are not evidence of successful production configuration.

## Exact operational limits
- Import jobs process server-side batches while the page is open or when Resume is clicked. No unattended worker/cron is installed. Finished staging survives refresh. An interrupted initial staging upload needs re-upload; incomplete jobs are not processed automatically. Product/customer imports remain foreground flows.
- All-time Agent and finance overviews are labeled all-time. Legacy detailed charts/list excerpts can still show newest loaded records; use the database summaries and Browse all records for exhaustive records. Historical imports have their own history ledger and are excluded from new-sales figures.
- Previous customer snapshot comparison requires a historical snapshot dataset and remains unavailable. A missing baseline is shown as unavailable, never fabricated.
- Custom labels supplement the stable pending/callback/completed/cancelled follow-up states. They are not new backend lifecycle states. Changing a configured return policy alone does not update courier returns before provider integration exists.
- The old local Hero-popup/scheduling forms are replaced by the real business/account/workflow settings. No unattended popup scheduler is commissioned.
- Custom widgets in this checkpoint are text/instruction widgets; an arbitrary data-source/chart builder is not implemented.
- Individual layout order applies to supported shop screens; the separate Creator platform overview is not managed by this shop-layout editor.

## Checks
- Build and whitespace/diff validation.
- Fourteen focused automated test files passed: original views and DOM click wiring, shop switching, workspace tools, product/customer/order operations, import mapping/locking, Auth/profile/email/Agent service and in-memory PostgreSQL migrations.
- PostgreSQL acceptance: hierarchy and escalation rejection, same-shop groups/distribution, one-record pull and own-queue RLS, deactivated-session rejection, finance arithmetic/COD balance, staged retry/idempotency, same-phone distinct history invoices, invalid-row isolation and cross-tenant denial.
- Browser QA with synthetic data: adding a custom widget rendered it; saving a delivery charge updated the displayed amount. No production records were touched.

## Resume before final delivery
Complete courier integration from the actual merchant documentation, decide whether unattended imports and advanced widget/scheduling features are required for the first release, then run production acceptance. Do not describe this checkpoint as “everything fixed/live”.
