JioFlow Update 107 — full-width purchase history rows

Requires Update106. Replace record-panel.mjs in the repository root, deploy and hard refresh. No SQL is required.

Each purchase now occupies one full-width row/card. Desktop layout separates customer details, highlighted purchased products and a distinct total amount panel. Order ID, date, status, phone, address, item quantities/line totals and notes are preserved. Long content wraps naturally. Mobile stacks content within the same full-width card.
Existing history ordering (newest purchase first inside View), list date ordering, pagination bar, top bulk controls, inline notes and permissions are unchanged.
Validation: combined imported/live cards, product/name escaping, inline notes, shared customer page, role-based controls/pagination and build. No live browser layout verification performed. Not deployed to production.
