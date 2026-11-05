JioFlow Update108 — attached bottom navigation and selection-only actions

Requires updates through107. Replace record-panel.mjs and workspace-design.css in the repository root, deploy and hard refresh. No SQL is required.

- The bottom pagination bar is straight, shadow-free and edge-attached: sidebar boundary to the viewport right edge, not the table/card width. Mobile spans the full width.
- Record pages scroll within the content area; sidebar, top area and bottom pagination remain in place. The outer application curve/margin is removed. Last rows have reserved space above the fixed bar.
- Shared content is centered with a 1280px maximum; record lists use 1200px with responsive side gutters.
- Bulk action bar is hidden when nothing is selected. Selection reveals count, Clear selection, Delete selected and Assign selected where authorized. Previous top Assign/Unassign and duplicate count are hidden. The Select-all-matching button is hidden; the table checkbox still selects the displayed page only.
- Delete confirmation and existing permissions remain. Agent cannot delete/distribute. Assign selected applies to customer profiles under existing assignment checks.
- Prior wide purchase cards, date sorting, imports and inline notes are retained.

Validation: no-selection/selection/clear states, Owner/Admin/Agent button permissions, pagination and existing customer/note regressions, bottom-bar geometry relative to workspace rather than card, production build. CSS layout has not been verified in the live browser; not deployed to production.
