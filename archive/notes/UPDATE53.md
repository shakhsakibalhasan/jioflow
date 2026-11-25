# JioFlow Update 53
Cumulative changed files after Update 48; includes Updates 49–52.

After backing up the existing JioFlow database, run Database53.sql in Supabase SQL Editor. It includes the idempotent Update52 reporting migration plus the new assignment RPC and follow-up lookup indexes. Do not run both Database52 and Database53 separately; Database53 includes both. Replace the included root application files, commit and redeploy Vercel. No environment key changes.

Assignment: shared single/bulk customer picker with one-user/equal-distribution tabs, name/email search, active shop Agents, group-based distribution and Permanent client checkbox. The server checks session, shop, staff permission and all selected customers/Agents before assigning in one transaction; equal assignment differs by at most one customer. The unchecked Permanent option preserves existing permanent clients. Existing unassignment remains available.

Follow-ups: reporting starts alongside the record list instead of waiting for it; lookup indexes support latest imported order, latest note and customer-order history. Existing caching retained. No rows are omitted to simulate speed; actual production timing still needs verification.

Confirmed orders by source: Website/Facebook/WhatsApp/Other cards update the chart in place, with count and percentage of total confirmed orders in the chosen period. All sources restores combined totals; source selection does not navigate away or trigger another request. The timeline remains limited to the latest 30 days, and this is stated in the UI. Counts cover the entire chosen period.

Local checks: picker selection/search/permanent; source chart selection/ratio/empty/all; PostgreSQL-compatible assignment 3/2 distribution, invalid Agent and caller denial; fast-workspace, workspace tools, main integration and supervisor Agent workspace tests; build and diff check. No live SQL, deployment, assignment or browser visual verification performed.
