# JioFlow update 010 — live order entry

Install:
1. If not yet applied, run migration 006 once. Then run migration 007_live_orders.sql once in Supabase SQL Editor. Migrations 001–005 must already be installed. Do not rerun previous migrations.
2. Extract this ZIP and upload its contents into the existing GitHub repository root, replacing matching paths. Preserve every other file and the assets folder.
3. Wait for Vercel Ready, refresh the main URL and select a shop.

Preserves the original order form and workspace design. Creator/Owner and Admins with the assign permission can save real orders: customer phone upsert, multiple products, quantity and price, discount, delivery charge, source, Agent assignment, draft/confirmed/ready-to-book status, preferred courier, notes and pending advance payments with method and transaction ID. Exchanges/replacements reference an existing order number.

Saving uses one database transaction, same-shop validation, amount validation, an idempotency key, payment duplicate protection and an audit timeline. All Orders opens live item/payment/timeline details and allows status/note/assignment changes before courier booking. Statuses from a courier cannot be forged by these forms. Draft or confirmed orders can be cancelled. Cancelled/booked orders cannot be edited by this release. Product/customer/order views still load up to 50 recent rows; product search queries the server by name. Agent workspaces remain gated pending the separate approval/device implementation.

Deactivate/Activate from update 009 are included. Email verification/SMTP setup has intentionally been deferred; existing authentication checks are preserved. No test/sample records are written to the production database.

Not yet complete: courier APIs, bulk import, full-dataset reporting, groups/distribution, permissions editing, uploads and settings persistence. The deployed Sites preview is separate from Vercel; the user must upload this package for the main Vercel site to change.

Validation: local PostgreSQL-compatible execution of migrations 001–007; duplicate-order retry, atomic payment failure rollback, totals, bad quantity/amount, tenant boundaries, status/note/assignment, Creator controls and session revocation. DOM tests verify order/cart/submit behavior and retained views. No production SQL, real orders, emails or courier booking were executed by the assistant.
