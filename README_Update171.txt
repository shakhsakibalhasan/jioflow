JioFlow Update 171 — Two-row Follow-up options

REQUIRES Updates 168, 169 and 170 and their prerequisites.

INSTALL
1. Run Database171.sql in the Supabase SQL Editor.
2. Replace EIGHT existing app files from this ZIP:
   custom-statuses.mjs
   record-panel.mjs
   record-cache.mjs
   online-client.mjs
   agent-workspace.mjs
   followup-filters.mjs
   original-sections.mjs
   workspace-design.css
3. Deploy through your existing GitHub/Vercel process and refresh the browser once.
No extra JS module or build-script replacement is required. Do not delete other files.

MAIN ROW
Search stays at the left. The horizontal primary row has Unassigned, Assigned, Completed, Permanent Clients and All, each with its own count.

SUB ROW
Unassigned: Never Assigned; Reassign; Agent Inactive; Customer Unreachable; Wrong Number; Follow-up Later; Already Follow-up; 3 Month No Response; 6 Month No Response; Cancel Data; For 1st Attempt; For 2nd Attempt; For 3rd Attempt; All tags. Existing custom active tags are included.
Assigned / Completed / All: Processing, Confirm, Refuse, No Response, Don't Call Again, Order Recently, Busy, Schedule, Problem Solve, Interested, Not Interested, For Relative, Irregular, FL-7 Days Later, FL-15 Days Later, FL-1 Month Later, FL-2 Months Later, FL-3 Months Later, All statuses. Existing active custom statuses are included; zero-result standard statuses stay visible.
Permanent Clients: New, any existing permanent statuses, All statuses.
Saved workflow labels are not renamed or reset. A status without matching records correctly shows zero.
Selected main/sub options are highlighted. Status shades retain their configured colors and fit the active light/dark theme. Both rows scroll horizontally on small screens.

FILTERING
Main bucket and selected sub-option are combined. Sub counts describe the selected main bucket before applying the sub-option. Main counts use the shared date/search/advanced-filter scope. Each displayed count is a customer count, not a count of historical order rows or repeated calls.
Completed uses the existing saved-follow-up completion rule and selected contact period from Update 168.
Normal page reads obtain scoped counts; fast reads show rows first and hydrate counts/details afterwards. Existing rows remain during inline tab loads. Requests remain scoped by authenticated client, business, Agent, date and search.
On entering Follow-ups without an explicit new two-row selection, staff defaults to Unassigned > Never Assigned. Applying date/advanced filters resets staff to Unassigned > Never Assigned while retaining those filters. Clicking a main/sub tab then selects that option without resetting the date/search.
Agent access is not expanded: Unassigned is disabled; Agents default to Assigned > All statuses, and all queries remain within their own assigned customers. A staff supervisor's Agent scope is passed to the new read RPC too.
Permanent remains available INSIDE Follow-ups. Its sidebar entry stays removed as requested. Existing Group popup and Assign/Reassign/Unassign fixes are retained.

NEVER ASSIGNED / LEGACY HISTORY
Never Assigned means there is reliable history that the customer has never had an Agent. New customers are tracked automatically; assigning and then unassigning a customer does not return it to Never Assigned.
Before Update 168, no separate assignment history existed. This update marks existing currently assigned/tagged/history-backed records as previously assigned. Untagged legacy records with unknown history are NOT guessed to be Never Assigned: they remain accessible in Unassigned > All tags, with an explanatory note when applicable. Therefore Never Assigned can initially show zero even while All tags has older customers. No customer is deleted.

LOCAL VALIDATION
SQL applied twice successfully. Six-customer fixture verified all five main buckets, per-bucket workflow/tag counts, Never Assigned versus previously assigned, fast/full row parity, date/search filtering and Agent/anonymous access guards.
Actual restored Follow-up panel verified the two-row mount, initial Never Assigned request, progressive counts and main-option click request. UI checks covered sub-options, selected state, counts, default/reset and history note. Existing status editing, Group/sidebar, assignment actions, phone search, client whitelist and static module graph checks pass.
No production deployment, live timing measurement or visual browser verification was performed. This patch does not guarantee the database/network can never time out.
