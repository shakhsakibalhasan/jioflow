JIOFLOW PREMIUM ORDER PULL — 2026-11-24

CHANGED FILES
- account-actions.mjs — Inline admin Order Pull options, Trackly-like row style (checkbox, source value, available count), admin-defined batch and daily limits, only saved values from imported data.
- workspace-tools.mjs — Agent Take More Orders modal shows only allowed Imported Status / Customer Tag 1 options with eligible count.
- workspace-design.css — Premium stable list layout, count pills and selected rows, JioFlow saved colors.

DATABASE
The following migrations were applied to the NEW JioFlow Supabase project already:
- agent_pull_source_option_counts_for_admin_panel
- restrict_order_pull_option_counts_to_agent_approved_pools
- count_agent_pull_pools_from_canonical_import_template_tags
- pull_agent_orders_using_import_template_tag1

Canonical tag source: jioflow_private.jf_history_summary117.payload->>'tag' (the same source used by the existing Follow-up filter). Old jf_order_history.details.reference_tag was not the canonical Custom Tag 1 source.
Counts are for unassigned, active, non-permanent customers with latest imported summary. One customer is counted once.
Server permission: authorized owner/admin/creator may inspect all eligible pools; an approved agent only sees their permitted pools.

DEPLOY
1. BACK UP the current GitHub main branch / commit and review changes.
2. Merge the three changed root-level files into the latest repository, preserving unrelated newer changes.
3. Commit to a test branch, deploy to Vercel Preview, confirm UI and no old source references.
4. Test Admin Edit Account: expand both lists, check counts, choose options, save, reopen.
5. Test Agent: queue empty, permission allowed, eligible counts, 20/batch and daily quota, concurrent pulls, and no duplicate assignment.
6. Test light/dark theme, scroll, tags, status colors and page navigation before promoting Production.

Do not upload the ZIP itself to GitHub instead of the contained files.
No new Vercel environment variables needed for this release.
Do not re-run database migrations that are already applied.

VALIDATION
node --check account-actions.mjs: passed
node --check workspace-tools.mjs: passed
node build.mjs: passed
DOM-dependent test suite could not execute in this sandbox because linkedom is absent; preview/browser test is still required.
