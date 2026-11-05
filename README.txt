JioFlow Update115 - requires Update114 and previous SQL112.
1. Run Database115.sql in Supabase SQL Editor.
2. Replace record-panel.mjs and workspace-design.css in repository root. Deploy and hard refresh.

Follow-up table: Latest status uses latest purchase status. Separate Agent status uses saved workflow, default Processing for untouched/pending profiles. Address is shorter, one-line with a full-text tooltip above on hover/focus. SKU column shows only latest purchase SKU, not product descriptions. Missing SKU is shown as a dash, not invented. Full product details remain in customer View, newest order first.

Local database role/date/filter regression and idempotent SQL checks, tooltip/default-status tests, existing customer/action UI tests and production build passed. No production deployment or browser visual verification performed.
