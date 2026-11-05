Update 100 - Match displayed Order Date to the selected range
Apply after Updates 96-99 (including earlier Database83/84/93).
1. Run Database100.sql in Supabase SQL Editor.
2. Replace record-panel.mjs in the same location, deploy and refresh browser.

Root cause reproduced: a customer qualified through a 9 September order but the list displayed a more recently uploaded 26 September order. The list now shows the most recent actual Order Date among orders matching the active date/source/tag/SKU/amount filters. A date-filtered amount also comes from a matching order, instead of the lifetime sum.
Imported dates come from the original template Order Date column when retained. Created At/upload timestamps are never substituted. Missing Order Date stays unknown. For legacy records without original columns, ordered_at/order_date are used. No year or original data is guessed. New live orders keep their actual creation date as their order date.
Single day and range use the same canonical order-date source; both range boundaries are included. Follow-up counts remain unique matching customer profiles (one normalized phone), not individual purchase counts. Full/fast queries and all-page selection retain existing role/tenant guards.
Date display normalizes ISO and day/month/year values consistently; use YYYY-MM-DD in CSV for unambiguous dates.
Validation: reproduced the 26 September vs 1-16 September mismatch before the patch; after patch the row shows 9 September and its amount. Tests cover single date, inclusive range, out-of-range exclusion, Owner/Admin/Agent, matching counts and selection, original 2023 template date over a 2026 stored value, absent Order Date, migration twice and foreign access denial. Calendar click regression, date formatting and build passed. No live deployment or live user database access performed.
