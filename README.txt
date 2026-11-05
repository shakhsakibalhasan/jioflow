JioFlow Update118 - Agent workspace and shared theme

Apply after Update115 frontend (latest Database117 recommended for large datasets). Replace all seven included root files in GitHub, deploy and hard refresh. No SQL for this UI/navigation update.

Agent Follow-ups: same shared search/tabs/table as management; no assignment control; remove summary/chart/filter sections. Agent Dashboard: keep first KPI summary boxes and only full-width Recent Orders below. Other roles retain dashboard sections.
Agent default navigation: Dashboard, Follow-ups, New Order; profile remains via account menu. New optional page controls in Owner/Admin Edit account > Permissions: Agent All Orders, Agent Permanent Clients, Agent Couriers. They default off unless explicitly enabled. Other delegated modules/actions continue to use existing permissions. Hidden pages are rejected by the client route guard; database row/action authorization remains the existing server policy (this update does not broaden it). Permission changes remain managed by Creator/Owner/Admin.

Shared workspace: 1200px centered content, consistent responsive side gutters, soft panel tint, white table surfaces, subtle borders/shadows. Existing user accent/dark variables retained.

Validation: agent navigation defaults/grants, dashboard metrics+Recent Orders retention, permission editor controls/grant payload, action/selection/pagination tests, scroll-preserving tab tests, JavaScript syntax and build. Production deployment/browser visual QA not performed.
