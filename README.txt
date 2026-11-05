JioFlow Update117 - Persisted imported-order summaries

Requires Database115 and prior updates.
1. If Database116 has not been applied, run included Database116.sql first.
2. Run Database117.sql in Supabase SQL Editor. This builds summaries for existing history once. Let this initial build finish.
3. Refresh JioFlow. No frontend files changed.

Each imported purchase has private parsed metadata; each customer has an indexed latest-imported-order summary. Transactional database triggers maintain insert/update/delete changes; no browser jobs or scheduled refresh are needed for these summaries. Historical purchases remain intact. The existing guarded reader still combines eligible live orders and preserves staff/agent restrictions and latest-date filtering. Cache tables/functions are not granted to authenticated API users.

Validation: idempotent migration, Owner/Admin/Agent latest-only filters, date boundaries, cross-shop denial, latest insert/delete fallback and row parity. Local 24k-customer test: 2642ms to973ms. Local 100k-customer test:11333ms to4207ms, identical returned rows/total. Synthetic one imported order/customer; not concurrent production load. No live deployment performed.

This reduces repeated history work; it is not a guarantee of zero timeouts or constant latency at unlimited scale. Live-server query plans/resources still govern final performance. This update does not implement background CSV import processing.
