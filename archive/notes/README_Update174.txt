JioFlow Update 174 — Five editable Follow-up tag sections

REQUIRES Update 171 and its prerequisites. Updates 172/173 were review forms, not installable patches; no 172/173 SQL is required.

INSTALL
1. Run Database174.sql in the Supabase SQL Editor.
2. Replace FOUR existing app files:
   custom-statuses.mjs
   record-panel.mjs
   workspace-tools.mjs
   online-client.mjs
3. Deploy through your existing process and refresh once.
Keep the remaining files from Update 171. No extra module or build-script change is needed.

WORKSPACE SETTINGS
The old three status/reason editors are replaced with five clear sections:
- Unassigned Tags
- Assigned Tags
- Completed Tags
- Permanent Client Tags
- All Orders Tags
Each has Add tag, Edit, Remove, color, display position and up/down ordering.
A saved tag list controls ONLY its corresponding Follow-up tab row. Removed tags are hidden from that section and do not automatically reappear from hardcoded defaults. Other sections and historical records remain unchanged.
Empty sections retain All tags / All statuses so records remain accessible. These aggregate controls are not user-created tags.
If Never Assigned or New is removed from its section, selection falls back to All tags / All statuses rather than applying an invisible filter.

DEFAULTS / COMPLETED
Completed starts with the same options as Assigned, including Processing. Completed still means an explicit follow-up save according to the existing completion rule: untouched default Processing records are not completed, but an explicitly saved Processing record can appear there. This follows the latest request to keep all Assigned options inside Completed.
Assigned defaults to Processing first and the Confirm-category status second. You can change ordering in Settings afterwards.
The fifth main option is labelled All Orders. It remains the existing all-customer Follow-up scope, not the separate native All Orders page in the sidebar.

TAG NAME AND FILTER VALUE
Tag name is the displayed label; Customer status / Saved reason is what it filters. Editing the display label does not rewrite saved history.
Choose an existing status/reason or create a new value. New workflow values are registered through the existing guarded status validator, so they can be selected when updating a customer. New reasons are registered for the Unassign reason picker.
Existing status behavior is shared and retained. Behavior/callback controls are disabled when matching an existing status; new statuses can choose a report category and callback days. Existing order-backed Confirm checks remain intact.
Removing a section tag does not delete its shared saved status/reason or other sections' references. Each section can be customized independently after its initial default list.
Never Assigned retains the history-aware definition from 171; unknown old assignment history stays accessible under All tags.
Permanent remains inside Follow-ups while its sidebar entry stays removed. Group, assignment, date filter and prior UI fixes are retained.

PERMISSIONS
Read/write guards reuse jf_status_settings. Only accounts with existing status/settings configuration permission can save definitions; Agents cannot gain configuration access. Changes are scoped to the selected business. New input names, values, colors, IDs and duplicate definitions are validated server-side.

LOCAL VALIDATION
SQL installed twice successfully. Tests covered all five defaults, Assigned/Completed initial parity, add/remove/reorder isolation, newly registered real statuses/reasons, malformed/duplicate input and Agent write denial.
UI tests covered five Settings categories, section-only removal, new displayed label with matching filter value, no removed-tag restoration, Completed Processing and All Orders naming. Restored Follow-up panel, status editing, group/sidebar, assignment actions and static module graph checks passed.
No production SQL/deployment or live browser visual verification was performed.
