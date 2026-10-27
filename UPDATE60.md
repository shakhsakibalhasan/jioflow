# Update 60 — Advanced Follow-up filters
Apply AFTER Update 59. Run Database60.sql once in your existing Supabase project. Upload the other changed files to the same GitHub repository paths, commit and wait for Vercel's build. No new environment variables are needed. This ZIP does not include or replace previous updates.

Follow-ups now has a narrow collapsed Filters bar. Expand it to edit choices, then Apply filters. Clear all removes filter selections. Date presets include Lifetime, Today, Yesterday, last 7/30 days, this/last month and custom dates; arrows shift the selected period. Dates use Bangladesh time and include the selected end day.

Controls match the supplied reference HTML's filter structure in JioFlow's theme:
- Order date; Created at from/to; Updated at from/to.
- Imported status (reference choices plus actual imported values), Agent, SKU, Order source.
- Connected / Not connected call groups, additional call outcomes, Positive / Intermediate / Negative customer categories and the shop's workflow statuses.
- Custom tag 1, 2 and 3. Choices come from this shop's imported original columns and existing tag settings; reference staff names are not copied into your shop.
- Payment amount: select one or more ranges from 100 to 10,000 BDT. Order total or recorded advance can be chosen. Multiple selected money ranges are combined with OR; other filters are combined with AND. Upper bands are exclusive at the next boundary, except the final 10,000 value is included. Recorded advance includes pending/verified recorded payments for live orders; it is not a claim that a courier remitted COD.

Historical order status, date, SKU, source, tags and money must match the same imported order. One customer remains one follow-up even with several matching orders. Live orders can match date, SKU, source and amount; Imported status applies to imported records only. Created/Updated dates apply to the customer profile; Order date applies to an order. Missing historical fields do not fabricate matches.

Only Creator, Owner and Admin see this advanced panel. Database calls reject Agent use, including a direct API request. Existing Agent follow-up work and record visibility remain scoped normally. Current section, active tab, pagination and filter-aware row/count retrieval are preserved.

Verified: PostgreSQL migrations through 042; combined filters and count consistency; same-order matching; range unions/boundaries; third tag; invalid input rejection; Creator/Owner/Admin success; Agent and other-shop denial; browser collapsed/expanded layout and multiple checkbox submission. Production deployment and a 500,000-record performance test were not performed.
