JioFlow Update 102 — chronological dates and immediate amounts

Requires Database100.sql and Database101.sql already applied, plus the Update101 frontend files deployed.
Run Database102.sql in the Supabase SQL Editor. Refresh the website and reapply the filter. No frontend replacement is needed for this update.

Changes:
- Fast customer lists now include matching order date and amount immediately, without waiting for the separate totals/details request.
- Customer pages sort by matching order date ascending, then customer ID, before pagination. Fast and full responses use the same ordering and matching amount.
- One phone remains one customer profile. If multiple orders match the range, the profile uses its latest matching order date/amount; other purchases remain in order history.
- Parsed MM/DD/YYYY CSV Order Date is stored once with an indexed column. Existing records are backfilled from the original date. New/updated history rows maintain this value through a trigger.
- Matching orders are computed as a batch per request, with explicit shop/role/Agent scope checks, instead of repeated guarded helper calls per customer.
- Counts and select-all keep their existing filters and authorization checks.

For the full September 2026 month select 09/01/2026 through 09/30/2026. The supplied screenshot selected September 1–15.
Missing source dates/amounts are not invented. Unique customer counts need not equal another system's order counts.

Validation: Owner/Admin/Agent dates, same-order amounts, inclusive boundaries, fast/full consistency, selection totals, ascending dates, trigger insert/update, repeat migration, cross-shop and anonymous denial. Local 3,500-record fixture: fast before ~673ms; after ~431ms; full after ~502ms. These are local measurements, not a production performance guarantee.
This update has not been applied to production. It reduces query work; it cannot guarantee that hosting/network/database requests will never time out.
