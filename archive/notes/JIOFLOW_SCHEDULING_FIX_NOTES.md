# JioFlow scheduling and refresh fix — 19 November 2026

This patch changes only these runtime files:

- `online.js`: retain the periodic security/approval heartbeat and inbox updates, but stop automatically rebuilding the whole workspace when another record changes. Users can continue using the existing Refresh control when they want updated rows.
- `custom-statuses.mjs`: normalize/deduplicate repeated status labels in the UI, including the single built-in **Schedule** option. Existing customer records and SQL settings are NOT deleted. A later settings save uses the normalized list.
- `followup-status.mjs`: reject a past/invalid callback datetime and preserve future scheduled callbacks.
- `callback-reminders.mjs`: check due callbacks every 5 seconds (when the tab is permitted to run timers), keep a visible popup, retry audible WebAudio after a user gesture if the browser blocks initial audio, and deliver an OS notification only where the browser has already granted permission. It does not ask for permission automatically.

Added `tests-scheduling-fix.mjs` (zero external dependencies).

## Local checks

```sh
node tests-scheduling-fix.mjs
node build.mjs
```

These checks ran successfully when this ZIP was prepared. **This is not an end-to-end production test.** The code was not deployed and the new Supabase environment was not accessed here.

## Important operational limitations

- The existing database reminder policy only generates due reminders for an **active assigned Agent** whose schedule is recorded under that Agent (per `Database62.sql`). Creator/Owner/Admin scheduling does not automatically create an Agent reminder under the installed database rule. This patch does not change that security rule.
- Audible alarms need an unlocked browser audio context (normally unlocked by interacting with the page), an open website tab and an audible device. Browsers may throttle background tabs or block autoplay. If browser notification permission is already granted, this patch also sends a desktop notification. It does not promise an alarm when the site is fully closed. For closed-browser reminders, a push notification/server-side job would be required separately.
- The fix does **not** migrate historical customer/follow-up/order records from the old Supabase project. Those records were intentionally excluded from the migration in the earlier workflow.
- No Supabase SQL migration, user roles, login approval, authentication, credentials or Vercel production settings are changed by this patch.

## Safe rollout

1. Keep a backup of the current production files and old Supabase project. Do not delete the old project.
2. Upload/commit the four changed runtime files (and optional test file) into a **new GitHub branch** and let Vercel make a **Preview** build.
3. Test with an active approved Agent who is assigned to a **test customer**: set Schedule to 1–2 minutes in the future, leave the JioFlow tab open, interact with the page to unlock audio, confirm the popup + sound once the time passes; test reschedule and complete to ensure old reminders disappear.
4. Check the Status dropdown shows **Schedule** only once. On Dashboard and Follow-ups, verify background heartbeats no longer rebuild the page, while explicit Refresh works.
5. Only after preview checks pass should you merge/redeploy Production. Verify the new Supabase project ID on the live site.
