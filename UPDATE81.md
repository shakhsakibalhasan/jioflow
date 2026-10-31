Update 81 — Template-based filter tags, compact filters and dashboard auto-scroll

Apply after Update 80:
1. Run Database81.sql in Supabase SQL Editor.
2. Replace followup-filters.mjs, original-sections.mjs, record-panel.mjs and workspace-tools.mjs in the application root.
3. Commit/redeploy and reload the application.

Template tags: Custom Tag 1/2/3 dropdowns come exclusively from the corresponding imported template columns (or canonical imported tag fields). They no longer merge configured reassignment labels, customer unassignment tags or unrelated reference tags. Empty values are omitted; whitespace is trimmed and duplicate values appear once. Existing imports with retained original_columns are supported without re-uploading. New imports are read when the filter panel is next opened. Options are limited to active customer records in the current shop; an Agent sees only options from assigned customers.

Matching: tag criteria use the corresponding imported order fields. Multiple custom-tag/date/other conditions must match the same order. Live customer unassignment labels cannot satisfy an imported tag criterion. Full/fast list paths and all-page selection follow the same rule.

Choices endpoint: authorize the shop/Agent once and aggregate scoped import data, avoiding per-history-row session/RLS checks. The caller's shop and Agent scope is checked explicitly.

Compact UI: smaller field heights, padding and group gaps; secondary group descriptions hidden; compact payment chips. A single Apply filters button is kept at the top. Changing values does not apply them until Apply is clicked.

Dashboard drill-down: clicking a linked metric/funnel/status box requests scrolling to the corresponding loaded record list. This applies to Agent, Admin, Owner and Creator shop dashboards. Scroll happens once after initial records load, respects reduced-motion settings, and does not run on normal list visits or pagination. It does not change the current role's permitted records.

Validation: raw template tag extraction; no assignment/reference defaults; trimmed distinct choices; combined conditions on the same order; all-page selection; Agent option scope; foreign-shop/anonymous denial; migration rerun. Local volume check with 10,000 additional imported orders returned choices in 779 ms (not a production benchmark). UI tests cover all roles, one Apply button, draft multi-filter selection, scoped supervisor workspace, page checkbox/delete regression, dashboard drill-down scrolling and ordinary-navigation isolation. Build passed. Not deployed live.
