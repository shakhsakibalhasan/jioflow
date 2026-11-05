JioFlow Update122 - requires Update120 files.
1. Run included Database121.sql if not already applied.
2. Replace all four included JS/MJS/CSS root files; deploy and hard refresh.

Top business/search/account bar and bottom bar stay outside scrolling content across workspace pages. Record pages retain page-size/pagination footer; other pages use matching footer. Header search beside business name submits name/phone to Follow-ups; on Orders/Couriers searches that page, including order IDs. Existing per-page search remains. Creator selects a business first. Agent scoping retained.

Includes Update121 permission/KPI fix: backend accepts sidebar permission keys orders/permanent/courier; boolean validation/caller restrictions retained. Management Follow-ups first confirmation tile now explicitly counts all active confirmed-flow business orders, including Agents, matching Dashboard order counts. Customer workflow tabs retain customer counts.

Validated: frame DOM/search destinations, real database permission saves/denials and shop-Agent order summary agreement, UI order KPI2 vs customer count0, action/retry/tab tests, syntax/build. Not deployed; browser visual QA not performed.
