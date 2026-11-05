JioFlow Update119 - Timeout investigation and confirmed fixes

Prerequisites: Update118 frontend and Database117 applied.
1. Run Diagnostics119.sql in Supabase SQL Editor and retain result tables. Read-only; does not return customer details. It reports installed function hashes/summary markers, table estimates, analyze state, indexes, connection waits and configured role timeout settings. SQL Editor timeout may differ from authenticated API role timeout.
2. Run Database119.sql. It changes only the filter-options reader to use private parsed summaries instead of reparsing every historical order; existing active-shop/agent scope guards retained.
3. Replace record-panel.mjs, deploy and hard refresh.

Confirmed UI defect: bulk selection bar was visible before the first successful list load. A timeout bypassed its selection-state paint. It now starts hidden and paints only from actual selection; empty failed loads clear stale selection. Retry explicitly invalidates client read caches before issuing a new read. Failed cache entries were already evicted; cache poisoning is not the established cause.

Database finding: list reads and filter-option reads are separate RPCs. Update117 optimized the former but did not replace the latter, which continued decoding entire original CSV history. In local 24k-customer/order test, unchanged filter-option result took 1340ms before and78ms after Update119. This does not establish the production list timeout cause or guarantee constant/unlimited performance.

Refresh repeats the same server work; changing browser UI cannot remove a deterministic server statement timeout. Live diagnostic results are necessary to distinguish missing/old SQL, resource pressure, locking, stale statistics or remaining expensive query plans. No live database access/deployment performed.

Validation: timeout->retry->successful rows, no-selection bulk hiding, select/clear behavior, cache invalidation/session scope, existing action/pagination tests, idempotent SQL/filter-option parity and build passed.
