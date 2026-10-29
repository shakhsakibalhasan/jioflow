Update 75 — Follow-up filtering and bottom pagination

Apply after Update 74:
1. Run Database75.sql in Supabase SQL Editor.
2. Replace followup-filters.mjs and record-panel.mjs; commit and redeploy.
3. Reload Follow-ups.

Filtering: Apply no longer waits for the optional filter-choice endpoint. Date/select/checkbox changes apply the current form values immediately; Apply filters also remains available. Loading choices preserves the current selected value. Custom date periods open the date controls. Previous/next period applies the new dates. Existing server-side date, status, source, agent, SKU, tag and payment conditions remain in effect.

Pagination below the table: Showing X–Y of Z, 20/50/100/200 rows per page, Previous/Next, current page input and total pages. Changing row size starts on page one. Row size is passed to the database rather than fetching every page. Existing callers without a row-size filter retain the old 50-row default. The chosen size is preserved when the filter form passes the current filter state. Selection across pages and Delete selected remain included from Update 74; selection ignores the rows-per-page limit.

Validation: database pagination at every size with non-overlapping pages; date/source/status/SKU/tag filters and full selection despite a small page size; date Apply despite failed choices; displayed ranges, last-page button and page jump; existing filter/record panels and selection/delete UI tests; build. Live deployment has not been performed.
