# JioFlow Update 52
Cumulative changed files after Update 48, including Updates 49–51.

1. Back up your Supabase database. Open SQL Editor in the existing JioFlow project and run Database52.sql once. It replaces only the reporting summary function and adds reporting indexes; no customer/order data is deleted. Requires the existing CRM migrations through 032. This SQL does not belong in Vercel environment variables.
2. Replace the supplied application files at repository root, commit and deploy through Vercel.
3. Reload Dashboard and All Orders. Confirm totals against actual records and test an Agent account.

The summary authorizes the session/shop once, preserves staff versus approved Agent scope, selects only reporting columns and joins distinct buyers instead of repeatedly searching orders per completed customer. Existing table RLS policies remain unchanged. No statement timeout increase or fabricated totals.

Dashboard geometry saved before this update is reset to the normal grid on load (titles, hidden flags and custom widgets retained). Save layout again to retain new manual placement/resizing. Internal status breakdown scrolling is removed so content can expand.

Includes previous compact all-role product cart, reporting filters beside New Order and comparison badges. Existing SQL from updates through 48 must already be installed; Database52 is an incremental migration, not a full database setup.

Validation: local PostgreSQL-compatible execution compared old/new totals; approved Agent scope, denied user/session and foreign-shop checks; 100,000 synthetic customers; summary failure/retry and layout editor tests; build and diff checks. Production timing, real-data results and browser visuals are not yet verified. No production deployment performed.
