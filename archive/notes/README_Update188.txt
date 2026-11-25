JioFlow Update 188 — Follow-ups, Agent reports and account updates

INSTALL (after Update 187)
1. Keep a backup of your current application files and database.
2. Run Database188.sql once in your Supabase SQL Editor. It is transactional and can be rerun.
3. Replace the root runtime files from this ZIP in your application project.
   Replace server/account-service.mjs in the server folder too; keep its existing path.
   Deploy the application through your normal process. Do not upload SQL into the public website.
4. Reload the browser. Existing logins and device approval rules remain in place.
No production deployment or production SQL execution was performed while preparing this ZIP.

CHANGES
- Assigned has three fixed options: Processing, Completed, All Statuses.
  Processing = no follow-up saved since the latest assignment.
  Completed = a follow-up saved since that assignment. Reassignment starts Processing again.
  Main Completed excludes untouched/reassigned records and has no Processing filter.
  Existing status history is preserved. Fixed Assigned options cannot be edited as tags.
- Agent Follow-ups hides Unassigned. Customer status filters include Positive, Intermediate,
  Negative for every Agent. The filter uses the existing scoped database API.
- Schedule asks for a date/time. Due reminders show a popup and a short sound after browser
  interaction enables audio. Closed browser tabs cannot play this in-app reminder.
- Purchase rate counts unique purchasing completed customers divided by completed customers,
  within the same Agent/reporting scope. Multiple orders by one customer count once.
- Agent report removes Overdue, Booked, Delivered and includes Not Connected.
  Agent and Group overview remove Orders Created and Booked summary cards.
  Agent and Group tables have Total footers; purchase rates are weighted.
  Shared group members are counted once in overall totals. Full group report stays table-only.
- Add Agent opens Add Account with Agent selected. Jio ID validation runs before invitation
  request creation; existing server authorization and cleanup rules are retained.
- Change password replaces Reset password. Owner requests an email recovery link, verifies it,
  then chooses a new password. The application requires fresh recovery proof (one hour).
  Authorized managers change Admin/Agent passwords in the existing guarded popup flow.
  Creator protection and login approval are preserved. SMTP/Auth delivery configuration is
  unchanged and must already be working; no real verification email was sent during testing.
- Agent edit shows browser/OS, device type, session state, login/approval/last activity.
- Logos follow light/dark theme with explicit surface support. Default site/favicon uses the
  black/brand asset for visibility. Google must recrawl its cached favicon; it is not immediate.
- Every Agent dashboard has 11 cards only: Assigned, Processing, Completed, Confirm,
  Purchase Rate, Connected, Not Connected, Due Callbacks, Positive, Intermediate, Negative.
  Lower charts/lists no longer fetch dashboard hydration data for Agents.
- Returning to an exact recent page/filter retains an inert visual preview while new data loads.
  Previews are memory-only, isolated by account/business/filter, cleared on login, limited to
  eight entries/one minute. Old preview controls cannot submit. Agent card layout is fixed
  rather than rearranged by old saved dashboard layouts.
- Existing customer cart stays at its current position, with rounded Save Order and price
  on the right. Confirm-only saving and the previous order-source correction are retained.

VALIDATION
Database188.sql applied twice on a local database snapshot; Owner/Agent/anonymous scopes,
full/fast filter parity, Processing/Completed partition and counts, reassignment, unique buyers,
purchase denominator, fresh/stale recovery checks passed.
UI checks: exact fixed options, Agent filter access, actual 11-card dashboard template with no
chart/list hydration reads, group drilldowns, weighted/deduplicated footers, Schedule date/time,
popup/audio once, theme logos, device display, inline order guard/source passed.
Account/API checks: managed Agent creation, authorization, direct managed password reset,
origin/identity validation, cleanup and no password exposure passed. Build module graph passed.

LIMITS
This is a tested patch, not a live deployment. Production statement timeouts, actual mail delivery,
real device audio policy and perceived page speed still need checking after deployment. This
patch reduces Agent dashboard work and page flashing; it does not guarantee every slow SQL
query is resolved or change compute/disk capacity. Owner verification is enforced in the app's
password flows; this patch does not install a Supabase Auth provider hook or change global Auth
password policy. No customer/order records or stored tag history are deleted.
