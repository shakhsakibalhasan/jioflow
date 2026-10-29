Update 73 — Follow-up statement timeout

Apply after Update 72:
1. Run Database73.sql in Supabase SQL Editor.
2. Replace record-cache.mjs in the application root, commit and redeploy.
3. Reload the application and open Follow-ups again.

The previous default-list optimization still counted all matching customers through per-row row-level-security checks. Staff list, detail/count enrichment and Agent totals now authorize the caller's access to the target shop once, then execute a shop-scoped read in a guarded database function. Agents continue through the original RLS implementations. The guarded helpers reject callers without staff access, including direct calls from Agents or another shop's Owner. No permission grants, customer rows or orders are changed. Existing functions are preserved as the Agent RLS path. The migration is safe to re-run.

Cache: revisiting a page reuses available rows while enrichment is pending, rather than waiting for that unfinished report.

Validation: result equality for full and fast customer pages and Agent totals; unchanged Agent RLS output; direct helper access denied to Agent/other-shop Owner; anonymous denial; repeated migration; cache regression; build; volume check. Results are local, not live Supabase latency measurements. This package has not been deployed to the live site.

Local volume check with 10,309 customers: fast list 59 ms; full page and counts 296 ms. In-memory PostgreSQL-compatible test runtime; not a production benchmark.
