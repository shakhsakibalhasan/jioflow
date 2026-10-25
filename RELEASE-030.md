# JioFlow 030 — complete order lists and quick revisits

Includes notification inbox update 029 and all previous source changes.

- All Orders now uses one sorted/paged union of new orders and imported historical orders. Imported rows remain read-only and never become courier bookings automatically. Existing matching live order numbers suppress duplicates.
- Recognized historical statuses map to appropriate tabs (Pending → draft, Complete/Completed → delivered). Unknown historical statuses remain Imported. All contains every accessible order record; first page shows 50, with next/previous pages for the rest.
- Tab counts and order overview counts use that same filtered set. Customer Unassigned still refers to customer assignments; customers imported without any order/history record do not become fabricated sales.
- Ordinary navigation/search/pagination does not show the full-screen logo. The full-screen logo remains for initial workspace loading and explicit Refresh.
- In-memory record pages are cached for 15 seconds, exact business/filter/page/session only, with in-flight deduplication. Save, import and Refresh invalidate the cache. No customer data is persisted in browser cache storage.
- Failed requests show an actual error and Retry instead of retaining a loading placeholder indefinitely.

Apply migration 022 / Database 029 first if not already applied, then JioFlow-Database-030.sql (migration 023). The source ZIP includes both SQL updates. No production database was modified here. Live data, pending statuses and imported field mapping still require verification on the primary site after deployment. Network/database latency cannot be guaranteed to be nanoseconds.
