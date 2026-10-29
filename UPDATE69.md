# Update 69 — Prevent dashboard KPI collapse from saved layouts

Apply after Update 68 (requires Update 67 runtime). Replace slot-layout.mjs and workspace-design.css and commit. No SQL, environment or data migration is needed.

The earlier repair looked only at the first matching summary container and rows with at least seven KPI tiles. It did not protect other summary containers, smaller rows with badly skewed widths, or legacy free-layout geometry. Normal-mode row CSS also allowed every tile to shrink into one long row. A stale saved row could therefore make labels and values unreadable again.

This patch:
- Adds CSS protection independent of the JavaScript repair: normal KPI grids use four desktop columns and two at narrower/phone widths. Saved flex rows wrap at readable card widths rather than squeeze into narrow strips.
- Checks every supported summary container, visible card widths, overcrowded rows and legacy free-layout geometry. Hidden tiles do not cause a healthy row to be reset.
- Recovers unsafe rows into the KPI grid. A trailing single KPI from the malformed row save rejoins the grid; its obsolete positioning class is removed so saved card order is respected.
- Preserves labels, figures, order, hidden state, event handlers, and healthy custom multi-card rows. No database layout or business data is automatically deleted/reset.
- Retains in-place layout editing and the compact phone UI.

Checks: regression tests for compressed four-card rows, 17-tile legacy rows, healthy custom rows, hidden cards, event handlers and existing editor interactions passed. In a local browser using the retained original dashboard, an intentionally bad 16-plus-1 saved-row fixture recovered four columns at about 242px per card. With JavaScript repair deliberately bypassed, CSS still kept cards readable and the page within the viewport. At 390px phone width the summary had two approximately 173px columns with no page overflow. Entering Edit preserved offset positions and sizes (a hover animation can move an individual hovered card by 2px visually). The preview uses synthetic empty records, not production data.

Production deployment and the exact production saved-layout payload were not accessed. These are downloadable source changes to deploy through the existing GitHub/Vercel workflow. After deployment, refresh the page to load the new files. If an older deployment remains active it will still have the old behavior.
