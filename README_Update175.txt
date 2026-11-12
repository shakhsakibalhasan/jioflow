JioFlow Update 175 — Fixed Never Assigned and clean tag settings

Requires installed Update 174 and its prerequisites.
1. Run Database175.sql in Supabase SQL Editor.
2. Replace TWO files: custom-statuses.mjs and assignment-picker.mjs.
3. Deploy through your usual process and refresh once.

Never Assigned is a fixed default filter, not a configurable tag. It always appears first under Unassigned, including when all reason tags are removed. It has no Settings Edit/Remove controls. Customers must have verified never-assigned history; previously assigned customers do not enter this option after Unassign. Older records with unknown assignment history are not guessed.

Unassign now requires an active Unassigned reason tag from the section settings. Both app and database enforce this. If there are no reason tags, add one in Workspace Settings first. Existing customer status/history is retained.

Assigned filters by latest saved status. Completed keeps the same status choices and additionally requires an explicit saved follow-up under the existing completion rule. Processing is supported in Completed after an explicit save. Existing date/search and Agent access restrictions remain in force.

Settings show one colored tag label per row, with Edit/Remove/order controls. Duplicate text beside the pill is removed. Removal confirmation is shortened.

Validated locally: SQL installed twice, fixed Never after empty/replaced lists, mandatory Unassign reason, five-section settings, latest status filters, Never vs previously-assigned filtering, date/search, Agent authorization and static build graph. Not deployed or run on production.
