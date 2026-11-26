JioFlow Update178 — Group distribution, group cards and Group Reports

Requires Update177 and its prerequisites.
INSTALL
1. Run Database178.sql in the Supabase SQL Editor.
2. Replace SIX existing runtime files:
   assignment-picker.mjs
   record-panel.mjs
   workspace-tools.mjs
   agent-reports.mjs
   online-client.mjs
   workspace-design.css
3. Deploy using your existing process and refresh once.
No new module or build-script change is required. No orders module is included.

DISTRIBUTION
Both single-customer and bulk Assign popups now fetch the current shop's saved groups. Choose Distribute equally, then a group. Its eligible active Agents are checked automatically. Selection count and exact allocation per Agent are shown before saving. Five customers across two Agents show 3 and 2. Editing the Agent selection clears the group selection and uses the manual selection. Inactive/removed Agents are not recipients. A group-read failure shows an explicit error rather than pretending there are no groups.

USERS & GROUPS
The lower User groups section is now populated from saved database groups instead of the empty legacy template. Each card shows group name, member count, active Agents, currently assigned customer count, member previews, View report, and permitted Edit/Remove actions. Saving/creating a group reloads the page and fetches the saved groups. Empty state is only shown after a successful empty result. Read failures offer Retry groups.

GROUP REPORTS
Agent Reports keeps its existing seven summary cards and charts and adds a separate Group Reports table. Full report opens the selected group's summary metrics, Revenue, Purchase Rate and individual member performance. Each member links to the existing detailed Agent report. Date selection is preserved when opening groups/members and retained when changing the period.

Group figures use the existing Agent Report service and its date rules. Customer metrics follow current assigned ownership and selected-period activity; orders use the existing report's selected-period order rules. Orders Created means native orders; All Orders follows the existing native/imported report scope. Group Revenue follows the same sales-value definition as Agent Reports. Only distinct membership IDs are included once inside each group; Purchase Rate is recalculated from combined buyers/completed counts, not averaged percentages.

Groups reflect CURRENT membership. Moving an Agent between groups changes which current group includes that Agent's report; this is not a historical group-at-sale ledger. An Agent can belong to multiple groups, so the same Agent may appear in separate group reports. No grand total adds overlapping groups together. Inactive, non-removed members remain reportable while being excluded from distribution. Removing a group leaves customer assignments/history intact.

SECURITY / VALIDATION
The new group read/count RPC requires an active staff session in the selected active business. Agent and anonymous callers are denied. Existing create/edit/remove/distribution guards remain unchanged.
Local tests passed: SQL applied twice; saved group read and unique member/count preview; group distribution and updated assigned count; cross-shop and Agent denial; live popup group loading; exact allocation and inactive exclusion; escaped group names; cards/actions; deduplicated report totals; group/member drilldown and period preservation; original create/edit popup, assignment role checks, restored Follow-up panel, summary layout and complete static module graph.
Not deployed or run against production.
