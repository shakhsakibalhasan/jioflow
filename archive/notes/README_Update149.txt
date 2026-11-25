JioFlow Update149 - Follow-up filter and list performance

Install after your existing database updates:
1. Run Database149.sql in Supabase SQL Editor once.
2. Replace followup-filters.mjs in GitHub, deploy and hard refresh.
No other application files need replacing. Existing import/audio/date patches remain.

Changes:
- Confirmation status definitions are read once per query rather than for every customer.
- Parameter-specific query plans for list/filter functions.
- Imported filter option columns aggregate in one history pass.
- Scoped indexes for customers, orders, notes, payments and order items; refreshed planner statistics.
- Filter choices share simultaneous requests and reuse a 30-second memory cache, separated by client/shop/session and local data revision. Failed requests are not cached. External edits appear after cache expiry or page reload.
- No statement timeout increase and no permission/RLS removal.

Validation:
Cumulative real local PostgreSQL-compatible tests passed. Migration applied twice safely.
Owner/Agent full/fast queries for dates, status, SKU and every option array matched before/after exactly. Foreign shop access remained denied.
With 8,000 additional customers, the same 26-call query suite took 16,065 ms before and 3,580 ms after in local PGlite (about 4.5x). This is a suite timing, not one production request or a live-site benchmark.
Build module check passed. Not applied to production.

No software can guarantee zero timeouts under every database load or network condition. If timeouts persist after deployment, production query plans and database load need inspection; do not keep increasing timeout limits.
