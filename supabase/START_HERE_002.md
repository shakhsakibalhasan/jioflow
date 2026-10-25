# JioFlow — Database update 002

This update prepares the CRM database. It does not change the website UI or enable the full online CRM yet. It contains no passwords, API secrets, sample customers or destructive cleanup commands.

## Run in your existing Supabase project

1. Open https://supabase.com/dashboard/project/xxsiwglshmqfqvbvxytw/sql/new . Confirm this is the JioFlow project.
2. Open `002_crm_foundation.sql` from this package in a text editor. Copy its complete contents.
3. Paste into a NEW SQL Editor query and press Run once. Do not paste it into a website HTML editor, GitHub editor or Vercel environment variable.
4. If successful, create another new query, paste `VERIFY_002.sql`, and Run. The version list should contain `002_crm_foundation`; the tables should have RLS enabled; the mutation-grant check should return no rows; the total should be 20 jf_* tables if no other JioFlow tables were added independently.
5. Send the success result or exact error message. Do not rerun migration 001. Do not delete tables to fix an error. This update is transactional: a failed initial run should roll back its changes. If 002 is already listed, do not rerun it.

Prerequisite: migration 001 from the earlier setup must already have succeeded. A missing-prerequisite error means stop and report it.

## What is prepared

- Products with active/inactive state, historical order item names/prices and separately protected costs.
- One customer phone per shop, one current follow-up per customer, callback/event history, permanent assignment and notes.
- Multiple items per order; agent assignment; order statuses and event history.
- Advance payment method, transaction reference and verification fields.
- Groups and membership links for distribution.
- Courier shipment/tracking records, booking deduplication and event history.
- Finance fields for courier/COD/packaging/return/product costs.
- Import job tracking and indexes for paginated lists and queues.

Tenant-aware foreign keys reject links to customers, products, group members or shipments in a different shop. Phone normalization (+880 vs local 01 numbers), CSV upserts, atomic order totals, status transitions and assignment validation will be implemented in the trusted write endpoints. The database alone does not implement them.

## Access in this stage

Creator and assigned Owners can read their applicable operational records. Active Admins can read their own shop; financial records require the explicit profit permission. Agents cannot query operational records yet: approved-device sessions and own-record policies must be implemented first. Anonymous visitors cannot read these records. Browser INSERT/UPDATE/DELETE grants are intentionally absent.

No service_role key should be pasted into chat, GitHub or frontend code. Privileged write endpoints will keep secrets in server settings.

## Next implementation

1. Trusted account/shop provisioning endpoints, role checks and verified-email invitations.
2. Password reset and server-enforced Agent approval/device sessions.
3. Transactional product/customer/follow-up/order endpoints and frontend integration.
4. Browser-data export/import, background CSV batches and real courier adapters.
5. Cross-device, tenant-isolation and end-to-end tests before regular business use.

Creating these tables does not transfer the browser-only Owner/Admin accounts or orders to Supabase. Do not clear browser storage until backups and migration are complete.

Validation performed for the package is reported in the handoff. The migration has not been executed in your Supabase project by the assistant; SQL Editor results are needed to verify execution.
