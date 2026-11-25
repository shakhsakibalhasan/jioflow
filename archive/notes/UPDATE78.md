Update 78 — filter design, page checkbox, workflow cards and role-scoped Follow-ups

Apply after Update 76 (Update 77 is included here):
1. Run Database78.sql in Supabase SQL Editor.
2. Replace these four files in the application root: followup-filters.mjs, record-panel.mjs, slot-layout.mjs, agent-workspace.mjs.
3. Commit/redeploy and reload Owner/Admin/Agent tabs.

Filters are grouped into Dates, Customer/source, Status/response, Tags and Payment. Fields have consistent sizes, selectable payment cards and responsive columns. Apply/Reset actions are available at the bottom. Choosing options only edits draft filters; Apply submits them together.

The checkbox beside Order Date selects/deselects only the visible page. The separate Select all matching records button selects every matching page. Selection and delete behavior from Update 74 remain available.

Workflow: remove legacy flex-row flags inside dashboard chart cards, restore four separate workflow cards and stack funnel rows vertically. The grid becomes two columns on smaller screens and one on phones. Card headings, data, actions and hidden flags are retained.

Role-scoped Follow-ups: Owner/Admin staff read paths remain shop-scoped. Approved Agents receive a fast read path that checks their current membership once and enforces exactly their previous RLS visibility for customers and live orders. Caller-supplied filters cannot remove those limits; metadata enrichment still uses the original RLS path. The supervisor Agent workspace also scopes all-matching selection to the inspected Agent.

Validation: full database regression fixtures; Owner/Admin populated lists; Agent fast-page equality against the prior RLS path for customer/order/status/date/page-size combinations; other-shop helper denial; repeated SQL. UI tests cover four workflow cards, vertical bar structure, page-only selection, all-page selection, delete confirmation, draft multi-filter Apply, layout controls, supervisor Agent workspace and build. No production data was changed and this package has not been deployed live.
