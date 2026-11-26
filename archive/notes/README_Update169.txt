JioFlow Update 169 — Group picker and sidebar cleanup

Requires Update 168 and its prerequisites.

INSTALL
1. Run Database169.sql in Supabase SQL Editor.
2. Replace THREE existing app files: workspace-tools.mjs, workspace-design.mjs, workspace-design.css.
3. Deploy using your existing process, then refresh once.
Do not delete other files or replace the whole repository.

CHANGES
Create/Edit group: compact checkbox beside each Agent, clickable row, selected brand shade, search by name/email/Jio ID, selected member count, Select visible and Clear selection. Name and at least one active Agent are required. Edit retains membership selection. The existing save process is retained.
Duplicate active group names are rejected with a clear message: edit the existing group or choose another name. It never silently replaces another active group's members. Backend checks are serialized per shop to handle simultaneous submissions. Inactive groups may reuse their name and reactivate with the chosen members. Hard-deleted group names remain reusable. Existing Owner/Admin access controls remain intact.
Sidebar ONLY: Permanent Customer/Client entry removed across Agent/Admin/Owner/Creator, including the nested Agent menu. Follow-ups remains. Internal Permanent tabs, filters, routes, records and functionality are untouched.

LOCAL CHECKS
Create/edit selection, name/member validation, search, visible selection, count, clear, payload and sidebar checks pass. SQL applied twice; create, rename, duplicate message, empty selection, inactive-name reuse, Owner/Admin group access and existing authority guards pass. Existing assignment and Agent Report UI checks pass. Static build module graph passes.

This ZIP has not been applied to production or visually verified in your live browser. The planned Trackly-style two-row Follow-up tabs are a separate change and are not included in this Group/sidebar update.
