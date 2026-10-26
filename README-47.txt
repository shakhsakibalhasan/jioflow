JioFlow Update 47 — cumulative changed files after Update 44. Includes Updates 45 and 46.

INSTALL
1. Run the COMPLETE Database47.sql in Supabase SQL Editor. Requires existing migration 030 (from Database43.sql). Includes 031 and 032; safe to rerun in this order.
2. Upload ALL ZIP source files to the same paths in your existing GitHub repository. Keep server/ modules, new agent-workspace.mjs/password-reset.mjs, original sections and build.mjs together. This is a patch, not a complete project.
3. Wait for successful Vercel deployment. Open https://www.jioflowbd.com/ and hard refresh. No new environment variables required; existing account/courier server keys must already be configured on Vercel.

CHANGES
- Shared spacing, field sizes, card surfaces, detail-page body/header/footer and explicit action labels. Flat ash/white brand theme; restrained fade and hover, reduced-motion support.
- Customer details/courier history grow naturally with content, including previously resized boxes. History cards wrap to new rows; no inner vertical/horizontal history scrollbar. Product catalog retains its intended scroll.
- Owner/Creator or permitted Admin: Account Access/Users -> View Dashboard opens the Agent's actual section layout with Agent sidebar, scoped lists/totals, New Order and tracking. Persistent viewing banner and Back to my workspace. Real signed-in actor is retained; no impersonation or credential exchange. New orders are assigned to the viewed Agent; audit actor remains the supervisor.
- Admin needs Manage users permission to enter a lower Agent's workspace, Assign customers / enter orders permission to save orders, and Workspace settings permission to edit layout. No access to higher roles or another business.
- Agent layout: enter the Agent workspace -> three-dot menu -> Edit layout -> move/resize -> Save. Agent-specific layouts are read when that Agent logs in. Normal shop layout is the fallback until an Agent-specific override exists. Agents themselves cannot edit layouts.
- Agent sidebar no longer shows inaccessible Account Access. Supervisor has an Edit Agent profile button; own account remains clearly identified.
- Fixed actual browser RPC whitelist omissions that blocked product/order editing despite database migrations being present. Missing migrations now show a specific message.
- Follow-up counts can appear immediately from a recent matching filter/session cache; secondary summary requests wait for the main record list instead of competing with it. Cache invalidates on saves. Supervisor scope context is deduplicated; layout fallback is resolved in SQL with a lookup index.
- Steadfast parser accepts numeric strings and nested data; unrecognized responses show unavailable instead of invented zero counts. Existing rate-limit cooldown stays intact.
- Update 46 managed password reset and Update 45 ash panels included.

VERIFICATION / LIMITS
18 automated test files passed, SQL migrations through 032 passed, production build passed. In-memory full app test verified Owner actor retained, Agent sidebar, matching scoped queries, New Order, layout namespace and Back. Browser QA with synthetic data verified 8 history cards, customer/history boxes expanding with no inner scrollbar, and unified inner edit-page styling.
No production Supabase SQL or Vercel deployment performed. Live Agent account, representative large-data latency/load and real Steadfast credentials/blocking were not verified. This does not guarantee zero latency or remove an upstream API block.

Source commit: 12c1b951b7447f58c49a4f86481fb6a8d840ce19
