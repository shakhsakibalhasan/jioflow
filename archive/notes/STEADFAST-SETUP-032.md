# JioFlow Update 032: Steadfast

Existing EcomDrive webhook stays unchanged. This release uses API polling and does not install or change any merchant webhook.

## 1. Install

1. Upload this complete source ZIP to the existing GitHub repository root, keeping its folder structure. This is cumulative through Update 031.
2. In the existing Supabase project's SQL Editor run `JioFlow-Database-032.sql` ONCE, after Database 031 (migration 024). Do not rerun earlier migrations. This installs migration 025.
3. Vercel must deploy the entire repository, including `api/` and `server/`. Uploading only `dist/` will not deploy the courier API. The existing build remains `npm run build` with output `dist`.
4. A separate earlier polling ZIP/table is not needed by this implementation. It does not automatically migrate that table's records. Do not run its old standalone workflow alongside this workflow. Existing API bookings outside JioFlow are not automatically imported.

## 2. Vercel Production environment

Open Vercel -> Jio-Flow -> Settings -> Environment Variables. Preserve working account-service values.

| Name | Value |
| --- | --- |
| `SUPABASE_URL` | Your existing project URL |
| `SUPABASE_PUBLISHABLE_KEY` | Existing public/publishable key |
| `SUPABASE_SECRET_KEY` | Existing server secret; legacy `SUPABASE_SERVICE_ROLE_KEY` is also supported |
| `JIOFLOW_APP_ORIGIN` | Exact production origin, for example `https://jioflowbd.com` without trailing slash |
| `STEADFAST_SHOP_ID` | The JioFlow business UUID, not a Steadfast merchant ID |
| `STEADFAST_API_KEY` | New private API Key from the correct Steadfast business profile |
| `STEADFAST_SECRET_KEY` | Its matching Secret Key |
| `STEADFAST_BOOKING_ENABLED` | `false` during setup |
| `JIOFLOW_POLL_SECRET` | Generate a new random 64-character secret in a password manager; use the same value in GitHub |
| `JIOFLOW_POLL_ENABLED` | `false` during setup |

Find the JioFlow business UUID as Creator in that shop -> Courier / Settings -> Steadfast -> Business reference. This requires the new code and database migration to be installed first. Alternatively copy the matching shop row's `id` from Supabase Table Editor -> `jf_shops`.

Keys shown in the shared PDF must be revoked and replaced. Never paste secrets into source code, browser storage, chat or screenshots. Server credentials belong only in Vercel, never in public VITE_/NEXT_PUBLIC_ variables. Redeploy after changing environment values.

Multiple shops: instead of the three single-shop credentials, use server environment `STEADFAST_SHOPS_JSON` with this structure (replace every placeholder privately):

```json
{"JIOFLOW-SHOP-UUID":{"api_key":"PRIVATE_API_KEY","secret_key":"PRIVATE_SECRET_KEY","booking_enabled":false}}
```

Each shop must use its own correct merchant business profile's credentials. No shop falls back to another shop's keys.

## 3. GitHub Actions setup

Repository -> Settings -> Secrets and variables -> Actions -> Secrets -> New repository secret:

* `JIOFLOW_POLL_SECRET`: exactly the same random secret saved in Vercel.
* `JIOFLOW_POLL_URL`: `https://jioflowbd.com/api/steadfast-poll` (use the actual production domain if different).

In the same Actions settings, Variables tab -> New repository variable:

* `JIOFLOW_POLL_ENABLED`: `false` initially. Change to `true` only after testing.

The workflow is `.github/workflows/steadfast-status-poll.yml`. Upload it at that exact path. It requires no GitHub plugin or Vercel cron subscription. Scheduled runs target minutes 7 and 37 each hour. GitHub schedules can be delayed/skipped. Each invocation processes up to 20 due shipments with locks; a workflow can request successive batches (up to 20) within its time budget. Remaining shipments are picked up on later runs. This is batching, not a shop/order package limit. Monitor Actions failures and last-sync timestamps as volume grows.

## 4. Verification at the end

1. Finish Steadfast ownership/KYC and email verification in the merchant portal. Booking may remain blocked until ownership is approved.
2. Confirm that the main JioFlow pages work and Courier says Configured. That label confirms server configuration, not a successful live API test.
3. New Order -> enter a valid customer phone. Check the Steadfast history; absent rates show a dash, never a clean-record score. This queries Steadfast only, not all couriers.
4. Set `STEADFAST_BOOKING_ENABLED=true` for the configured shop and redeploy (or set the shop's JSON `booking_enabled` to true).
5. Save one genuine test order as Confirmed, then open its details -> Book with Steadfast. This creates a REAL parcel. Confirm COD and recipient details. New Order also supports Confirm & Book when Steadfast is selected.
6. COD equals the server-calculated total minus recorded non-rejected/non-refunded advances. Pending recorded advances are included, matching the order summary; confirm actual receipt before booking. A COD ledger is not proof of courier payout.
7. Check the Consignment ID in JioFlow against Steadfast. Never create a fresh order to retry a timed-out booking. The same saved order keeps the same courier invoice. An ambiguous success/duplicate response may need reconciliation in the merchant panel before continuing.
8. Enable `JIOFLOW_POLL_ENABLED=true` in Vercel and redeploy. GitHub -> Actions -> JioFlow Steadfast Status Poll -> Run workflow. Check the counters and the saved order status.
9. Set GitHub repository variable `JIOFLOW_POLL_ENABLED=true` to enable scheduled runs. Keep EcomDrive's webhook URL and token untouched.

## What changes in JioFlow

* Booking records a real shipment and tracking identifiers, with per-shop and Agent permissions checked in the database.
* Courier/order details can refresh status on demand; Steadfast caches status for 60 seconds.
* Polling updates the existing Orders table, shipment timeline and the next dashboard/report query. It does not force an open page to reload.
* Approval-pending outcomes stay Booked until Steadfast confirms them. Delivered maps to Delivered; partial_delivered maps to Partial Delivery; cancelled maps to Cancelled. Cancellation is not proof that a physical return was received. Return-receipt tracking, pickups, exchange booking, balance/payout reconciliation and other couriers are outside this release.
* Partial delivery does not automatically infer partial COD receipts. Received courier payouts remain a manual ledger.
* Real keys, deployment settings and live parcel tests were not performed while preparing this package. Account verification behavior is unchanged.
