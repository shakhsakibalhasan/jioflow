# Update 65 — Progressive lists and reduced background traffic

Requires Update 64 application/database. Install Database65.sql first in Supabase SQL Editor, then replace the seven application files at repository root and commit. Vercel must build using build.mjs. No hosting plan change or new environment variable is required.

## Behavior
- Customer/Follow-up/Order queues fetch initial rows before secondary reports. Customer name, phone, status and assignment are interactive as soon as the first request completes. Amount, latest note, order date and counts fill in after the existing full query finishes. Temporary unknown fields use a dash; they are not recorded as zero.
- Normal full API remains compatible. The fast initial query skips summary aggregation, customer metadata calculations and, where status permits, the global buyer scan. Both paths use the same filter rules, pagination and row-level permissions.
- Enrichment updates row cells without replacing the table, selection or event handlers. Failed secondary loading keeps the list and shows a retry message. Fresh cached full results avoid both requests on an immediate revisit. Saving invalidates the cache.
- Routine order/customer/product saves refresh business records without re-fetching all shops/profiles/memberships. Account, shop and permission changes retain the full refresh. The current page stays selected. During targeted refresh, previous rows remain visible but temporarily inert until fresh rows replace them, preventing stale actions.
- Background session/workspace/Agent checks share one RPC per visible-tab interval. Inbox is included at most every 30 seconds when closed; opening or acting on notifications still refreshes it. Checks resume on focus. Session revocation and Agent approval checks remain enabled.
- Concurrent notification refreshes in the same session/shop are coalesced. An unchanged set of due callbacks no longer re-fetches the inbox every reminder polling cycle.
- The build emits module-preload hints for 43 local modules, allowing parallel fetching across import levels. Files remain separate; this is not a minified bundle. No secret/server files are preloaded.
- Adds queue-sort and case-normalized order-reference indexes. Exact large filtered totals and history still require database work; they are not approximated.

## Verification and limits
Database migrations through 046 passed locally: fast/full row IDs and totals agree across queue statuses; deferred metadata, tenant isolation, Agent advanced-filter denial, anonymous denial and combined heartbeat/inbox behavior were checked. Progressive timing tests confirm rows return before an intentionally delayed report, cached revisits make no new request, and save invalidation works. Record panels/actions, cache, Agent scope, notifications and callback-controller checks passed; production build and preload targets passed.

Live database execution plans, authenticated end-user timings and 50-user load tests have not been measured. No production SQL, domain or deployment was changed by this ZIP. It improves the loading path and avoids unnecessary work but cannot guarantee instantaneous results or a particular speed multiplier. Real timing depends on network, database load, filters and data volume.
