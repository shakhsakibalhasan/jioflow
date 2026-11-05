JioFlow Update 105 — phone profile merge and original order customer details

Requires prior updates through 104.
1. Run Database105.sql in Supabase SQL Editor.
2. Replace record-panel.mjs in the repository root, deploy and refresh.

Rules:
- Same normalized phone, different Order IDs: one customer profile with separate historical orders, even when names differ.
- Same normalized phone and same Order ID: update the existing order; no duplicate purchase row.
- Order IDs remain unique within the shop. An ID already belonging to another phone is rejected rather than silently moved.
- Latest order status continues to follow the newest actual Order Date (Update103), independent of upload order.
- Each new/reimported order now stores the supplied name, phone and address inside its purchase details. Cards show those per-order customer details along with products, ID, date, amount and status.
- Older imports use their preserved original CSV columns when available. A missing original name cannot be reconstructed automatically; reimporting supplies it.
- Existing optional phone-only/no-ID import behavior and access controls remain unchanged.

Validation: actual staged importer with normalized phones, differing names/IDs, repeated identical ID, changed-name same ID, per-order snapshots, one customer profile, latest status after an older order upload, repeated migration; historical CSV name fallback, card rendering, inline note regressions and build.
Tested locally, not deployed to production.
