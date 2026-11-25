Update 44 — cumulative patch after Update 41. Includes Updates 42 and 43.
Upload ALL files at their existing paths to your existing GitHub project. Wait for Vercel deployment and press Ctrl+Shift+R.
If Database43.sql has already run successfully, no new SQL is required. Otherwise run the included Database43.sql first (requires existing migration 026).

Latest changes:
- Desktop Delivery details, Order summary and Products stay side by side, including laptop widths.
- The full long product CARD is retained: PNG artwork + name/SKU/price + Add button.
- White outer card, light brand hover. Only the separate image backdrop is transparent; no card removal.
- Shared New Order layout verified for Creator, Owner, Admin and Agent. Role permissions stay unchanged.
- Top-level assets versioned and static cache revalidation configured to reduce old UI remaining after deployment.
- All Update 43 changes included: live-only Orders, imported records retained in follow-up/history; shared Dashboard layout, full Status Breakdown, top KPI grouping, full detail pages, pre-booking order editing, group bulk assignment and layout movement controls.

Local checks passed; browser checked white cards and aligned three-panel tops without page horizontal overflow. Live deployment and courier provider calls were not performed. Existing JPG/PNG artwork with white pixels embedded in the image is not background-removed by this CSS change.
Source: a24f6eba98f7c6d3b6168d7fc84344bbb168f0e1
