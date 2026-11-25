JioFlow Update167 — faster basic customer lists, Agent controls and assignment preview
Apply after Update166. Summary boxes remain in Main Dashboard, Profit and Agent Reports; All Orders retains only Confirm, Profit (with permission), Revenue, Delivered, Returned, In Transit, Ready to Book and Booked.

INSTALL
1. Run Database167.sql in Supabase SQL Editor. Transactional; tested twice.
2. Replace all nine application files in this ZIP at the repository root.
3. Deploy and hard refresh once. No production changes were made by the assistant.

INCLUDED
- Large dashboard summary boxes removed from all other sections, including Follow-ups, Permanent Customer and Couriers, during initial mounting. Main Dashboard, Profit and Agent Reports retain their boxes. Lists, status tabs/counts and filters remain. All Orders retains eight compact summary boxes; its profit/revenue finance request follows the selected reporting period. Other sections no longer request separate dashboard summary/KPI totals.
- Default staff customer list selects the page before expensive order metadata enrichment. Advanced filters, searches and other statuses continue through the existing filtered implementation. Eight exact before/after JSON comparisons passed (direction, page size and Agent scope). Local fixture timings: 326ms before / 152ms after for eight requests combined. These are local test numbers, not production guarantees.
- Assignment picker has native visible checkboxes, selected-Agent count and exact per-Agent customer allocation. Remainder follows the same sorted membership IDs as the database. Group selection resolves to the active Agents shown in the preview, so the submitted allocation matches it. 20 customers / 3 Agents = 7,7,6.
- The retained Create group button now calls the real save flow. Admins can manage Agent groups in their shop; existing permission-enabled Agent-manager group access is retained.
- Admins can activate/deactivate/remove Agents in their own shop even without general user-management permission. Cannot manage Owners, Admin peers, Creator, self, or foreign-shop Agents through this additional authority. Owner and Creator access retained. Deactivation blocks access and revokes sessions while retaining assignments/history. Remove clears assignments and group membership, retaining business history, as before.
- Edit Agent profile includes read-only Devices & sessions with browser/OS, approval status, first login, approval time, last activity and Active now indication. Online is based on a recent 90-second presence check, not proof that a person is interacting. Existing device approval process is unchanged. No IP address is invented when none was recorded.
- Sessions now persist in local browser storage and existing tab-session credentials migrate once. Temporary network/server failures do not erase the session. Handles refresh-token rotation if another tab has already saved a newer token. Explicit logout, account deactivation/removal, administrative revocation, deleted/invalid auth sessions and actual server-side expiry still stop access. Browser data clearing can also remove a login. Single-device approval remains. Supabase Auth session time-box/inactivity policy must separately allow the intended duration; the app cannot bypass revoked/expired credentials.
- Heartbeat no longer fails for non-Creators when the optional Creator-only password-reset feed denies access. The denied feed remains empty; permission is not broadened.
- Removed the Updating workspace transition label. Same-section updates may retain an inert preview; a different route never displays the previous route's details as its own.

CHECKS
SQL migration twice; eight default-list exact-result comparisons; Owner heartbeat with inbox; Owner/Admin group creation; Admin deactivate/reactivate; Admin cannot deactivate Owner; device read permissions. UI exact allocation, native checkboxes, device rendering, network failure/session retention, refresh, Follow-ups overview removal. Existing account actions, workspace rendering, order form, status summary and search checks. Syntax and static 49-module build passed.

LIMITS
Not a claim that all site bugs/timeouts are eliminated. Production Nano CPU/memory pressure can still require compute adjustment after query optimization. Whole-site exhaustive filter/date-range and live browser visual validation were not performed in this patch. Advanced filters remain on the prior implementation. Approval behavior was not replaced with Trackly's behavior.

Agent Reports: seven top summary cards use theme metric styles. Lower duplicate aggregate summary cards removed. Orders by Agent and Overall Purchase Rate retained. Existing per-Agent drill-down metrics retained.
