# Update 61 — Zero payment range and Follow-up Amount column
Apply AFTER Update 60. Run Database61.sql once in the same Supabase project, then upload the other changed files to the existing GitHub repository paths and commit. No environment-variable changes are required.

- Payment filter starts at BDT 0: the first checkbox is now 0–499. Existing bookmarked 100–499 filters are treated as 0–499 for compatibility. Remaining bands and the inclusive 10,000 upper boundary are retained.
- Follow-ups table displays Amount in place of Orders count. Amount is the customer's combined recorded order value from live and imported orders. A matching imported external Order ID and live order number for the same customer count once, using the live value. Missing/invalid imported values are ignored; unavailable totals show a dash instead of a fabricated zero. This is order value, not profit or received payment, and includes all recorded order statuses.
- Other customer/order pages retain their existing columns. Other filters and role restrictions remain unchanged. Amount is a profile total; applying an order filter selects profiles but does not turn this column into a paid/COD or filtered-period subtotal.

Verified with fixtures and PostgreSQL: zero and under-100 matching, old-filter compatibility, combined totals, duplicate-reference handling, missing values, RLS shop isolation and visible Amount/currency formatting. Production deployment has not been performed.
