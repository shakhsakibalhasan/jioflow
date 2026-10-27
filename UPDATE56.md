# JioFlow Update 56 — changes after Update 55

Apply on top of Update 55. This ZIP contains changed application files only.
No new courier integration, API configuration or courier service changes are included.

## Install
1. Run `Database56.sql` once in Supabase SQL Editor. It contains migrations 037 and 038; previous updates through Database55 must already be installed.
2. Replace/add the files from this ZIP at the SAME paths in your GitHub repository. Keep all other files.
3. Commit together, then allow your existing Vercel deployment to finish. Your existing `node build.mjs` build copies the two new modules.
4. Refresh the site. No account/customer/order data is removed by this update.

## Layout
- Open a page's three-dot menu → Edit layout. Editing happens on the page.
- Drag the grip left/right inside its current row. Dropping on another row is ignored.
- Only ↑ / ↓ changes rows/sections. Form cards remain within their own form so order fields retain their bindings.
- Hide/Show is on each box; hidden boxes appear as faded editable boxes while editing.
- Drag the corner to change height and relative width. The other boxes adjust their width within the same row.
- Save layout persists; Cancel restores the previous layout. Existing business data is unaffected.
- Owner/Creator and authorized Admin keep layout editing. Agents cannot edit their own layout. Existing supervisor Agent-workspace editing is retained.
- On narrow phone screens rows stack for readability; the saved logical row is retained.

## Daily / Monthly Top Performers
- Top Performers has Daily / Monthly tabs, Edit, and Celebrate.
- Settings → Top Performer Celebrations → Edit schedule opens the same controls.
- Daily: enable/disable, multiple time slots, today/yesterday selection, add/remove times, default schedule.
- Monthly: enable/disable, day of month and time. It ranks the CURRENT month to date, not the previous completed month. Dates beyond a month's end use its final day.
- Optional message and Preview buttons. Times use Asia/Dhaka.
- Defaults: automatic showing is OFF until enabled. While the panel is open, schedules are checked every 30 seconds. A missed slot is checked when a workspace next opens. This is an in-app popup; it does not send an offline email/push notification.
- Each slot is shown once per account/business/browser session. A new browser session/device can show it again.
- One winner plus runners-up, avatar, confirmed count, sales, delivered/returned/cancelled and share of confirmed orders. Ranking is confirmed orders, then sales value, then membership ID for deterministic ties.
- Only real live orders count. Imported historical records do not enter the leaderboard. Active Agents only.
- Agents never receive profit values from the leaderboard RPC. Owner/Creator/authorized staff can see profit when permitted; missing cost is shown honestly.

## Settings / statuses / tags
Sections are arranged vertically in the JioFlow theme: Account Details, Order Money & Workflow, Top Performer Celebrations, Custom Statuses, Permanent Client Statuses, Unassign Tags, Page layouts.
- Account/profile/password and business-charge workflows retain their existing controls. Agent profit remains unavailable.
- Add, edit, remove statuses; color picker + hex code + live badge preview.
- Choose the report category: pending/intermediate, confirmed/completed, positive, negative/cancelled, no response, busy, callback.
- ✓ selects the confirmed follow-up status. Calendar selects the status that asks for callback date/time. Preset callback days are supported.
- Custom statuses appear in the existing follow-up View → Status dropdown, including Agent views. Saving applies the selected light form color and updates reports using its configured category.
- A follow-up Confirm status does NOT itself save a new order or book a courier; the existing Create Order → #new → final confirmation flow is preserved.
- Permanent Clients have a separate configurable list, initially New.
- Unassign tags have Add/Edit/Remove and color/hex preview. They are shown on customer rows and as clickable filters in Unassigned. Bulk Unassign offers the configured tags.
- Remove hides a status/tag from new choices; existing customer labels/history are retained. Renaming updates matching current customer labels for that business. Historical follow-up events remain unchanged.
- Definitions/settings are per shop. Agents can use permitted statuses but cannot configure them.

## Verification
Passed local PostgreSQL-compatible execution through migrations 037/038, including cross-shop/anonymous/Agent-write denial; Agent profit privacy; callback validation; status rename/color/tag persistence. Passed focused UI/DOM tests for layout row lock, arrows, hide/save/cancel/resize, schedules, custom status dropdown/color, tags, and existing follow-up-to-New-Order and all-role New Order parity. Sample layout and celebration card visually checked in a local browser preview.
No authenticated production tests, real courier booking, live SQL execution, or production deployment was performed here.
