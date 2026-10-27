# JioFlow Update 61 + 62

## Install
Requires Update 60 / database migration 042.
1. If Database61.sql has not been applied, run it once in Supabase SQL Editor. If already applied, skip it.
2. Run Database62.sql once, after Database61.sql.
3. Replace the application files in this ZIP at repository root and commit. Vercel rebuilds using build.mjs.

## Included
- Update 61: payment range begins at 0; Follow-ups Amount replaces order count, with live/imported references deduplicated.
- Schedule reminders: only the Agent who personally saves the schedule receives its popup and private notification. Owner/Admin/Creator and other Agents do not receive it. Schedules saved by supervisors do not generate an Agent reminder.
- In-app popup includes Close and Open follow-up. Opening navigates directly to the customer and marks the notification read.
- Future reminders are hidden until due; rescheduling, completion and access loss suppress obsolete reminders.
- Reminder ownership is preserved during note-only edits.
- Fixes client permission list for the advanced filter-options RPC from Update 60.

## Timing and availability
The signed-in Agent panel checks a server-based deadline and rechecks every 10 seconds. An open, active panel displays the popup when the reminder becomes due; network delays, sleeping devices and browser timer throttling can delay it. No operating-system push notification is installed. With the browser closed, the reminder remains stored and appears on the next authorized login. Existing schedules are retained only when their recorded last updater is their currently assigned Agent.

## Verification
Local database suite through migration 044 passed: private recipient scope, future visibility, read-all safety, duplicate prevention, popup acknowledgement, reschedule/completion and supervisor exclusion. Popup controller, notification controls, customer record panels/actions and production build passed. Production database/deployment has not been changed by this package.
