JioFlow Combined: Order Pull + Saved Tag Colors + Stable Layout
============================================================
No live deployment or production database change was made when this archive was generated.

ORDER PULL
- Admin/Owner/Creator opens Edit Agent > Configure Take More Orders.
- Defaults: OFF, 20 customers per pull, 50 customers per day, empty Processing queue required.
- Admin allows Imported Status and/or Customer Tag 1 choices, including Delivered and Return.
- Agent may choose one allowed option in Follow-ups and pull eligible unassigned customers.
- Admin controls all permissions server-side; only an approved active Agent session can pull.
- SQL performs atomic row-locked assignment and a daily quota check (Asia/Dhaka).
- Uses the latest imported history record per customer, not an outdated status.
- The old unrestricted workspace_tools pull route is intentionally disabled by migration.
- Note: in a previous read of JioFlow, order-history reference_tag values were empty. If so, Customer Tag 1 will have zero eligible records until imported data has a valid Tag 1 field. Do not treat Imported Status as Customer Tag 1.

TAG/STATUS COLORS
- First-paint appearance uses the saved app palette before CSS loads.
- Server-resolved tag/status palettes are cached without user/customer information, then revalidated.
- Rows are painted synchronously using the cached final status/tag colors.
- Color transitions/animations are disabled; tab geometry/scrollbar gutter is reserved.
- Newly saved changes invalidate cache and reload canonical values.

SAFE RELEASE
1. Backup current GitHub branch and JioFlow database. Merge these changed files into a fresh test branch; do not blindly replace newer changes.
2. Test the SQL migration in an isolated Supabase branch/clone. Validate owner/admin permission to edit agent settings; default disabled. Validate duplicate agent pull, daily quota, queue empty, Tag1 without imported values, and legacy-pull denial.
3. Apply SQL only with tested frontend release, then deploy Vercel Preview and test final colors while navigating between Follow-ups tabs and Settings.
4. Confirm responsive layout, Agent Login Approval and Page Navigation; only then deploy to Production.
5. Avoid using your public service-role key in frontend files.
