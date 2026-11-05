JioFlow Update 106 — top bulk controls, fixed pagination and quieter spacing

Requires Update105 frontend and previous database updates. No new SQL is required.
1. Replace record-panel.mjs and workspace-design.css in the repository root.
2. Deploy and hard refresh (Ctrl+Shift+R).

- Selection, clear selection, select-all-matching and Delete selected are above the record table. Existing deletion confirmation and permission checks are retained. Agents do not gain deletion permission.
- Rows per page (20,50,100,200,500,1000), Previous/Next and page-number navigation are in a fixed bottom bar, aligned with the list on desktop and adjusted for mobile. Space is reserved below rows to prevent covering the last records.
- The bottom bar hides while a customer/action page or modal is open.
- Shared site styles reduce card/widget shadows, standardize normal panel padding (22px desktop,16px mobile), section/grid gaps (20px desktop,16px mobile) and form spacing. Existing theme colors, readable font sizes and focus treatment remain.
- Previous import, matching dates/amounts, latest status, purchase cards and inline notes are retained.

Validation: shared Owner/Admin/Agent DOM checks for bulk-bar position, delete visibility, selection and page navigation; customer/history/note regression checks; production build. Layout CSS prepared for desktop/mobile; no live browser or production verification was available. Not deployed by this package.
