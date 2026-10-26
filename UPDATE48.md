# JioFlow Update 48

Changed-files package, cumulative after Update 44 (includes Updates 45–47).

## Install
Extract into the repository root, replacing matching files, then commit and deploy through Vercel. Do not upload the ZIP itself as application code. Existing environment variables remain unchanged.

No new database migration in Update 48. If Database47.sql has not already been applied, apply it before testing managed password resets or supervisor Agent workspaces. Do not apply it again if already completed.

## Changes
- Equal-width New Order columns with consistent gaps, including previously saved fixed-width layouts.
- Customer form rows grow naturally, preventing Order type / Original order ID / Source from overlapping the next row.
- Courier history is a separate full-width row above customer details, hidden with an empty phone. Existing branded provider cards retained for every role.
- Main dashboard KPIs normalized into the upper grid after loading saved layouts; four long chart panels retained on wide screens, responsive on smaller screens.
- Agent report summary cards use the main dashboard metric markup and styling.
- Dashboard data hydration retains live metric nodes and chart containers rather than rebuilding the whole dashboard and rebinding all tools.
- Short-lived, per-client/session/shop/finance-scope hydration cache, request deduplication and save/refresh invalidation.
- Customer details has an inline product editor. Unbooked live orders can be edited. Customers with only imported history can explicitly create a draft from the inline cart. Imported history remains unchanged; this does not auto-confirm or book a courier.
- Section navigation uses browser history entries. Back/Forward restores prior section, shop and filters. Refresh preserves section and saved workspace scope. Existing detail-page Back returns to its parent page.

## Validation
19 automated UI/client/service regression files passed, including live RPC allowlist, Agent workspace scope, all-role New Order parity, blank-number history hiding, inline cart creation/edit, retained dashboard nodes, cache isolation/invalidation, and section history restoration. Build and syntax checks passed.
Browser layout check with synthetic data verified equal three-column widths/gaps, all customer fields inside their container, and four equal-height long chart columns despite old fixed dimensions.

## Limits
No production deployment, real customer mutation, courier booking or live credential-based history lookup was performed. Database/network/provider latency remains measurable only with a live authenticated session. Dashboard chart source data retains the existing bounded record hydration; this update does not replace chart aggregation SQL.
