Update 72 — combined Follow-up, Import and Agent login approval fixes

Installation after Update 69 or later:
1. Run Database71.sql, then Database72.sql in Supabase SQL Editor. If Database71.sql was already applied, it may be run again safely.
2. Replace these three application files in the repository root: live-customer-import.mjs, online.js, notifications.mjs.
3. Commit and redeploy. Reload Owner/Admin and Agent tabs after deployment.

Follow-ups: default All page selects 50 customers before joining follow-up details. Counts no longer require joining every customer's follow-up. RLS, search, filters and exact totals remain enforced. Added supporting indexes. Live query duration must still be measured with production data.

Import: selecting a file only prepares it; Import starts writes. History staging uses 200-row requests and a single SQL insert per chunk. Progress separates uploaded rows from processed rows, tracks confirmed processing, and reaches 100% only when processing completes. Rejected rows are not included in the final imported total. The bar spans the card width. No hard file row limit is implemented; large-file throughput has not been established.

Agent login: an older delegated-approval RLS policy called a private function without caller EXECUTE permission, causing the login queue SELECT to fail. It is replaced by a dedicated permission-checked helper. The original queue also used user-management permission while approval used approval permission. The queue now follows approval access. Pending requests have a dedicated section in the bell even when absent from the latest 50 activity notifications. Partial notification request failures no longer discard successfully loaded approvals. The login notification trigger is restored idempotently. Self-approval and access to other businesses remain blocked.

Validation: database migrations and duplicate-stage/import/approval access checks; fast/full record parity; notification rendering and actions; import progress; build. These changes were prepared locally, not deployed to the live application.

The separate pending courier Update 70 work is not included in this package.
