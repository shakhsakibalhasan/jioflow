# JioFlow design restoration 006

1. Extract JioFlow-Design-Restore-006.zip.
2. Upload its files into the existing GitHub repository, replacing files with matching names. Keep the folder structure.
3. Wait for the Vercel deployment to finish successfully.
4. Open the main site and hard refresh (Ctrl+Shift+R). Sign in using the existing Supabase account.

No new SQL or environment variables are required for this update. Database migrations 001–004 must already be applied.

Restores the original workspace styling from styles.css: sidebar, icons, top business selector, five Creator summary tiles, business overview, account distribution, compact user cards, grouped account lists, shop workspace navigation and dashboard panel layout. The gradient login and current live product/customer/follow-up operations remain connected. The legacy browser-local authentication and sample records are not loaded or erased.

Customer and follow-up counts use authenticated server totals under existing RLS. Unavailable figures and comparisons display a dash, not fabricated values. Profit, order reports, courier integration, Agent approvals, imports, groups/settings editing and other unfinished operations remain unavailable and are labelled accordingly. This update restores the visual framework; it does not complete the entire CRM backend.

Creator can open a shop from Shops. Changing the top selector keeps the current section; selecting All Shops returns to platform scope. Accounts are scoped to the selected shop.

Validation: local auth/account API tests, workspace rendering and integration tests, operational UI tests. Browser visual review used isolated layout fixtures, not a real signed-in user session.
