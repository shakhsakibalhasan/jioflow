JioFlow Update152 - Shared site performance improvements

1. If Database149.sql is not applied, run it first. Then run Database152.sql once in Supabase SQL Editor.
2. Replace ALL EIGHT .mjs files in this ZIP in GitHub, deploy and hard refresh:
   online-client.mjs, record-cache.mjs, agent-workspace.mjs, agent-reports.mjs, followup-filters.mjs, online.js, workspace-design.mjs, record-panel.mjs
Keep your existing Update147 date fix and Update148 audio/CSS files.

Changes across pages that use the shared client/cache:
- Identical concurrent table reads/counts and explicitly allowlisted read-only RPCs share one network request. Different shops, filters, session versions and mutation revisions remain separated.
- Save/status/create/delete/approval/import requests are never merged by this new layer.
- Cached page keys ignore JSON property order; pending reads stay shared until completion, then the normal 10/15-second cache lifetime begins. Each consumer receives its own copy to prevent accidental cache modification.
- Agent wrapper caches have a 20-entry limit instead of growing on every mutation indefinitely.
- Agent Report polling pauses while the tab is hidden, a dialog is open or the user is editing; normal scheduled checks resume afterward.
- Includes Update149 filter-choice caching and database optimizations.

Validation: new performance test (20 identical reads become one request), request failure retry, shop isolation, write separation and copy isolation passed. Existing client payload/denial, record cache, Agent workspace, status-cell and build/module checks passed.
Older Agent Report markup snapshot tests expect the preexisting old name-only cell and fail against the current avatar/name/email cell; no report cell markup was changed here.
No live deployment or real-browser whole-site latency benchmark performed. This reduces unnecessary work but cannot guarantee zero lag under all network/server loads. No production database settings or timeout limits are raised.

Search fixes in Update152:
- Submitted text/phone stays visible in the top search bar after page redraw.
- Global search results hide the second lower search toolbar; the top search remains active.
- Customer rows remain visible while order history/details are fetched, rather than showing a blank results area.
- In-page search records its term in navigation state and suppresses identical submits while already loading.
- DOM test verified top search persistence, lower-toolbar hiding and visible customer results while deferred details load.
This ZIP includes all Update150 changes; use this package alone for these application changes.

Automatic workspace updates in Update152:
- The existing approximately 5-second visible-tab heartbeat carries a small business-scoped change stamp. This is polling, not WebSocket push. No changed stamp means no automatic page reload.
- Customers, follow-ups, notes, orders, payments, items, shipments, import history, products, membership/profile/shop details and workspace settings mark changes. Normal Agent heartbeat session touches do not mark changes unless session status changes.
- Login approval reloads profile/membership directory data; pending login/approval status changes also mark a directory change.
- Updates refresh automatically when safe. Open dialogs, typing, selected checkboxes, layout editing, imports and new-order/settings/profile forms defer automatic redraws. Those form pages update after leaving the form or using an explicit refresh.
- A guard checks again after network reads so typing started during a background fetch is not overwritten.
- Current list page, page size, search and view scroll are retained during automatic refresh.
- Update failures leave a Refresh message; no forced browser reload or discarded unsaved form.
- SQL uses statement-level transition tables and a transaction-scoped stamp. No customer content is stored in the stamp table, which app users cannot read directly. Shop access and approval/session guards remain.

Validation: cumulative local database suite, twice-safe Database152 migration, directory/customer change detection, unchanged-session stamp stability and own/foreign-shop access checks passed. Sync coordinator tests cover unchanged data, edit deferral, failure retry and scope reset. Search, client, cache, status and release build checks passed. No live deployment or multi-device production timing test performed.
This package includes Update150/151 changes; install this package for the combined performance/search/automatic-update work.
