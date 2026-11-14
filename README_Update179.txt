JioFlow Update179 — Compact Group Reports layout

Requires installed Update178. No SQL required.
Replace ONE app file: agent-reports.mjs. Deploy as usual and refresh once.

The Agent Reports overview keeps its existing seven cards, Orders by Agent chart, Overall Purchase Rate and Agent table. Below it, Group Reports now follows the same layout: seven themed cards (Total Groups, Online Now, Assigned, Confirm, Orders Created, Booked, Revenue), Orders by Group donut, Overall Purchase Rate, and All Groups report table.

Group Full report now shows only the group heading/member information and individual member performance table. No summary tiles or charts are shown on that group detail view. Table columns follow the Agent performance metrics and include Revenue, Purchase Rate and an Agent report link. Date filters and selected reporting period carry through group/member navigation.

Overview summary totals count each group-member Agent once, including when an Agent is in multiple groups. Group chart/table values describe each group separately; shared members can overlap between group values. Existing reporting definitions, current group membership, shop permissions and database remain unchanged.

Local checks passed: seven Agent cards preserved, seven Group cards and two charts, chart/full report links, no summary/chart in group detail, member navigation, date preservation, existing assignment/group-card checks and complete static module graph. Not deployed on production.
