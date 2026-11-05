JioFlow Update 113 — Table text containment

Apply after Update112.
Replace record-panel.mjs and workspace-design.css in the repository root, then deploy and hard refresh. No SQL required.

Fixed column geometry keeps Order IDs, names, addresses and notes inside their own cells. Long IDs/names use ellipsis and native full-text titles. Addresses show up to two lines, with full address on hover or keyboard focus title. Small viewports scroll the table horizontally. Action buttons remain in one row. General card/detail text wraps long words.

Validated locally: JavaScript syntax, existing action/selection/pagination DOM tests, and production build. Production deployment and browser visual verification have not been performed.
