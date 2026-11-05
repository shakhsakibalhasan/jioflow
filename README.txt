Updates 96 + 97 - Follow-up date/amount filters and Agent Report query
Apply after Update 95 (including earlier Database83/84/93).
1. Run Database96.sql in Supabase SQL Editor.
2. Run Database97.sql in Supabase SQL Editor.
3. Replace followup-filters.mjs in the same location and deploy; refresh browser. No build.mjs changes needed.

Follow-up: Created At/Updated At controls removed. Order Date calendar shows two months on desktop, stacked on mobile. One click selects a day; a second click selects an inclusive date range in either direction. Done closes calendar; Apply filters commits all drafts and closes the main filter panel. Existing period presets remain. Clear date removes date restrictions.
Amount: compact content-sized chips; multiple ranges remain supported. Exact amount input matches a single order total (or recorded advance when selected), not customer lifetime sum. Typing exact amount clears ranges; checking a range clears exact amount. Exact amount and date/source/tags are checked on the same order.

Agent Report: existing explicit shop-management permission guard retained. SECURITY DEFINER avoids repeated row policy evaluation during aggregation; tenant filters remain in query. Added indexes for active assignments, orders and activity. Existing reporting access is unchanged: Agents cannot view management reports. This addresses a code-level timeout risk; the user live error was not available, so live resolution requires checking the report after applying.

Validation: Owner/Admin/Agent calendar draft UI, both range directions, exact decimals, date clear; SQL migrations applied twice, exact amount + date on same order, full/fast Owner and Agent paths, authorized report counts, foreign/Agent/anonymous report denial. Existing Apply and report UI tests and build passed. No production access, deployment or live visual browser test performed.
