# Update 66 — Compact phone UI and readable layout editor

Requires application Update 65. No SQL or environment setting changes.
Replace these four files at repository root and commit: workspace-design.css, slot-layout.mjs, workspace-tools.mjs and platform-layout.mjs. Wait for the production build, then refresh.

Phone styles apply only up to 600px viewport width: two-column KPI grid, 112px KPI cards (116px at the narrowest breakpoint), 150px bar charts, smaller rings, tighter cards/gaps/forms and compact filter spacing. Inputs remain readable at 16px. Business data and sections are not hidden. Normal desktop and tablet styling is preserved.

The layout editor no longer installs duplicate controls on structural wrappers such as Stats, Dashboard panels and restored-view containers. Widget IDs are assigned before filtering, retaining existing actual-widget IDs. Each widget has one local move/hide/drag control strip with room above its content. Desktop edit rows keep a readable minimum card width; overcrowded rows can scroll inside that edit row instead of squeezing cards or overflowing the page. Drag stays within the row; use the existing arrows to move across rows. Phone editing stacks widgets for usable controls. No existing saved layout is automatically reset or deleted.

Checked: layout row drag/arrows/hide/show/save/cancel/form retention/proportional resize tests; structural-wrapper filtering; legacy dashboard geometry repair; syntax/build. Browser QA on a local Owner dashboard at 390px confirmed 112px KPI/150px charts and no page overflow. At 1280px normal desktop KPI geometry and full page height exactly matched the baseline. Phone/desktop edit controls had no structural duplicates or page overflow. Other roles share these styles and editor modules; real production data and every custom saved layout have not been visually tested. Nothing has been deployed to the production domain by this ZIP.
