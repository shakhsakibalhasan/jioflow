# JioFlow 025 — faster opening and stable record lists

Includes the complete 024 source update. If Database 024 is already installed, run only Database 025 (migration 021). If your database is still through 018, apply Database 024 first, then Database 025. The source ZIP includes all prior changes.

- Record pages open their actual toolbar/tabs immediately with a small loading area. Their paged query starts before optional workspace layout/settings/report work.
- These pages no longer fetch a newest-50 excerpt, its order items, payments, finance and follow-ups before requesting the final paged list. The old excerpt cannot flash and disappear while the full panel replaces it.
- Workspace status, Agent approval and business/account data are requested concurrently; all access gates still complete before content renders.
- Notifications no longer block page refresh; duplicate pending-login reads were removed. Stale notification responses cannot overwrite a newer business selection.
- Optional current/previous reports, finance and Agent totals start concurrently. Unused shop-dashboard count queries were removed; the platform overview still loads its business counts.
- Short entrance motion respects reduced-motion preferences. Record rows remain visible during in-panel requests; rapid pagination is guarded, and late old responses cannot overwrite the current panel.
- Fixed fallback links for Negative, Positive, Intermediate, Attempted, Not attempted, Failed, Purchase rate and callback boxes.

- Status tabs show small inline counts, computed over the same business/Agent/search/source filters as the list. One database response returns records, matching total and all status counts; no request per tab and no count inferred from only the first 50 records.
- Hidden operations no longer preload a duplicate record page on every navigation; they initialize only when an edit/history action needs them.

## What boxes connect to
All lists honor current business and account visibility. Order reports use the selected reporting dates; most customer cards describe current customer profiles. Categories overlap and should not all be summed together.

| Box | Underlying condition | Opens |
|---|---|---|
| Total customers | Current customer profiles | Follow-ups / All |
| Assigned / Unassigned | Agent assigned / no Agent | Follow-ups / matching assignment |
| Completed | Follow-up marked completed | Follow-ups / Completed |
| Completed on Orders/Courier | Order delivered | All Orders / Delivered |
| Pending follow-up | Pending or callback follow-ups | Follow-ups / Pending |
| Cancelled | Follow-up cancelled, or order cancelled on order pages | Respective filtered page |
| Connected | Connected, positive, negative or intermediate outcome | Follow-ups / Connected |
| Not connected | Not connected, no answer or busy outcome | Follow-ups / Not connected |
| Positive / Negative / Intermediate | Exact call outcome | Follow-ups / matching outcome |
| Not attempted | No call outcome or not_attempted | Follow-ups / Not attempted |
| Attempted | Any recorded outcome except not_attempted | Follow-ups / Attempted |
| Failed | Attempted customer without a non-draft/non-cancelled order | Follow-ups / Failed |
| Due Callbacks | Callback timestamp is due or overdue | Follow-ups / Callbacks |
| Permanent clients | Permanent customer flag | Follow-ups / Permanent |
| Total orders | All orders in the period | All Orders / All |
| Confirmed | Orders other than draft/cancelled; includes later delivery stages | All Orders / Confirmed |
| Ready to Book | Confirmed or ready_to_book status | All Orders / Ready to Book |
| Booked / In transit / Delivered / Returned / Partial delivery | Exact order status | All Orders / matching status |
| Imported | Saved historical ledger; date filters use its last update timestamp | All Orders / Imported, read-only |
| Revenue | Total value of non-draft/non-cancelled orders | All Orders / Confirmed |
| Purchase rate | Completed follow-up customers with a confirmed order ÷ completed follow-up customers × 100 | Follow-ups / Buyers |
| Profit | Saved revenue less recorded costs; missing costs indicated | Profit details |
| Courier COD Pending | Delivered expected COD less recorded receipts | Courier / Delivered |
| Top performer | Selected Agent's report | Agent Reports / that Agent |

Connected is not a synonym for confirmed. Completed follow-up is not automatically delivered. One customer can have multiple orders. Assignment, call outcome and order status are separate dimensions. Imported history stays separate from the All live-orders total and is never booked as a new order automatically. Courier values currently come from saved local records, not unconnected external APIs.

## Validation and limits
20 regression files passed, including PostgreSQL migration/RLS/count checks and delayed-response tests. Browser QA with synthetic records verified immediate Follow-ups/All Orders shells and inline tab counts while optional reports were artificially delayed. UI navigation no longer waits for optional requests, but live database/network latency still determines when new records arrive. No claim is made that every production device, data volume or courier integration has been verified.
