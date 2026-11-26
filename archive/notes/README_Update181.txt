JioFlow Update181 — Faster Follow-up counts, separate ordinary inbox refresh

REQUIRES Update180 and its prerequisites.
INSTALL IN THIS ORDER
1. Run Database181.sql in Supabase SQL Editor FIRST.
2. Replace ONE existing app file: online.js.
3. Deploy through the usual process and refresh once.
No other runtime modules or build files are needed.

FOLLOW-UP COUNT OPTIMIZATION
The full customer page query now builds its accessible, search/date/advanced-filtered customer scope once, derives the selected bucket from it, and calculates the five main tab counts from the same scope. The Follow-up wrapper no longer runs a second full page query just to get main counts. The fast rows path keeps early bucket filtering and skips main count aggregation. Selected rows, pagination, status/tag counts and current assignment rules remain unchanged. Orders branches retain the Update180 repair and are not modified by this optimization.

APPROVAL / SESSION CHECKS
The existing visible-tab heartbeat interval stays at 5 seconds, including the focus check. Session revocation, account access, workspace status, device approval gate, presence and change stamp checks remain on every heartbeat. Pending login approvals and password-reset approval queues also remain on EVERY heartbeat, including light calls. Ordinary notification feed is fetched on first heartbeat, on shop/user scope change, and at 30-second intervals. Manual notification refresh still fetches immediately.
Apply SQL before replacing online.js so the lighter heartbeat already returns approval queues when the frontend starts requesting it. Ordinary notifications may arrive up to about 30 seconds later during normal polling; this interval does not apply to approval/security checks. Existing hidden-tab behavior is unchanged.

LOCAL PERFORMANCE
Same PGlite database fixture with 20,063 customers / 4,563 assigned:
Follow-up full counts before: 2636,2683,2778 ms; after: 817,783,823 ms (median about 70% lower).
Fast first page before: 187,146,145 ms; after: 161,147,137 ms.
These are local warmed sequential measurements, not live Supabase latency or a production throughput guarantee. Database size, concurrency, compute and network affect live results. This change targets Follow-up count work and ordinary inbox polling; it does not claim every report/query is optimized.

VALIDATION
- SQL applied twice successfully.
- Exact rows/total/subcounts and five main counts matched before/after across 15 bucket/date/advanced-filter combinations.
- Never Assigned, previously assigned exclusions, Processing, completed, status and fast/full/date/search regressions passed.
- Order statuses and fast/full queries still passed the Update180 regression.
- Owner/Admin actual light heartbeats returned login/reset queues without ordinary feed; Admin order/Follow-up access passed; Agent own-data and anonymous-denial checks passed.
- Frontend harness checked seven consecutive 5-second heartbeats: inbox only at first/30s, pending approval delivered at 5s, forced sign-out handled immediately.
- Identical concurrent reads still deduplicate; writes are not merged; complete static module graph passed.
No production database changes or deployment performed.
