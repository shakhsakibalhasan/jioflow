# JioFlow: One-click Agent Take More Orders + taken_by database field

## Frontend
- Agent's Take More Orders button no longer opens the Imported Status / Customer Tag 1 selection modal.
- It refreshes Admin-approved permissions and available counts before calling `jf_agent_pull_auto({target_shop})`.
- Agent does not submit a status/tag selection; the server chooses from Admin-approved pools.
- The existing Processing-queue empty-state, Admin settings, and availability messages remain.
- `online-client.mjs` API allowlist includes `jf_agent_pull_auto` and its mutation revision invalidation.

## Database (already applied to the connected Supabase project)
- `public.jf_agent_pull_auto(uuid)` enforces approved Agent session and delegates actual assignment to existing secure `jf_agent_pull_take`, which enforces saved permission, queue-empty gate, batch size, daily limit, and atomic customer assignment.
- `public.jf_order_history.taken_by` is now a real `text` column. A BEFORE INSERT/UPDATE OF details trigger derives it from incoming `taken_by` or legacy Custom Tag 3 template mapping.
- Historic records are NOT bulk rewritten; their legacy Tag 3 values remain in `details` and historical summary. The new column is set on new/updated imported history rows.
- No live customer orders were assigned during preparation or testing.

## Deployment
- Merge changed source files into current GitHub main (do not overwrite later changes).
- Run build and tests, then deploy through your existing Vercel process. Database updates are already applied and should NOT be rerun.
- Test using an approved Agent session with an empty Processing queue. Clicking Take More Orders should assign up to the Admin's saved batch/daily limit and show the newly assigned Processing records.
- Live end-to-end assignment is unverified: testing against live customers was intentionally avoided.
