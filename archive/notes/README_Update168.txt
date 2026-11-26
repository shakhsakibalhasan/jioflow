JioFlow Update 168 — Date filters and retained dashboard totals

REQUIRES Update 167 (and its prerequisites) already installed.
Not deployed or applied to your production database automatically.

INSTALL
1. Run Database168.sql in the Supabase SQL Editor. It is transactional and safe to run again.
2. Replace these FOUR existing app files with this ZIP's versions:
   workspace-tools.mjs
   record-panel.mjs
   followup-filters.mjs
   online.js
3. Deploy the changed files through your existing GitHub/Vercel process, then refresh the browser once.
Do not replace your whole repository or delete other files.

WHAT CHANGED
- Confirm customer counts require a real non-draft/non-cancelled native order in the selected reporting period. A customer counts once, even with multiple orders.
- Profit and Revenue now use the same selected reporting period, including the main Dashboard and Profit page. Existing known-cost calculation is retained.
- Follow-up period selection no longer silently becomes an imported/latest ORDER DATE filter.
- Customer lists, counts, dashboard and Agent Report customer cohorts use activity in the selected period: customer creation, recorded assignment change, saved follow-up, or native order creation. Assigned means currently assigned customers with that activity; it is not a count of assignment operations.
- Completed means unique customers with a saved follow-up in the period whose current saved status qualifies as completed. Multiple saves for one customer do not multiply it. Contact/outcome summaries show the current saved state of period contacts, not a historical replay of every status change.
- Orders use created_at with inclusive start and exclusive end. Existing date picker uses Bangladesh calendar boundaries.
- Advanced Order Date is independent of the activity-period picker. Period changes reset pagination.
- Same user/shop/Agent/page/period refreshes retain the last successful metric values. Failed refreshes no longer replace those values with dashes. Another user or another period never receives that cached value.
- The existing navigation preview waits for initial metric hydration as well as layout. First visits without cached data still use placeholders; it does not invent data or suppress authorization errors.

HISTORICAL LIMITATION
Old customer assignments did not store a separate assignment timestamp. This update starts an exact private assignment history for future changes; it deliberately does not guess old assignment dates from updated_at. Older customer activity can still be found from saved follow-up events/last_contact_at, customer creation and native order timestamps. Existing assignment dates cannot be reconstructed when no history exists.

SCOPE AND VERIFICATION
This fixes the identified date/count mismatch and metric disappearance path. It does not guarantee a network request can never fail or resolve all database capacity/timeout issues. The initial full-screen Failed to fetch startup failure remains a separate diagnostic path.

Local PostgreSQL-compatible tests:
- Update applied twice without error.
- Three-day order fixture: Today=3, Yesterday=2, Last 7 Days=7; Confirm list and dashboard agree.
- Finance revenue agrees with selected-period order totals.
- Empty period gives zero dashboard/list/Agent Report counts.
- Multiple status saves for one customer count once; Completed list agrees.
- New assignment enters activity scope; private history access denied to app role.
UI checks: same-scope metric retention, user/date isolation, independent period/order-date wiring.
Existing status editing, order form, assignment and Agent Report layout checks pass. Build module graph checked.
No production timing or live browser verification was performed.
