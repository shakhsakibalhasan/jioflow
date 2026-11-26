# JioFlow — Workspace Filter Names & Import Mapping

## Included
- Workspace Settings → **Filter & Import Column Names** → **Edit names**.
- Editable imported status, order source, Custom Tag 1, Custom Tag 2 and Custom Tag 3 labels.
- Default third tag name is **Taken By**.
- All labels are display names; internal filter keys and previously saved order/customer records remain intact.
- Downloaded import template uses configured headings.
- Uploads with the configured headings map back to the existing data keys.
- New `Taken By` values are mapped into Custom Tag 3 by the live database compatibility update.
- Existing Tag 3/other customer values are not rewritten or deleted.

## Applied in new Supabase
1. `public.jf_filter_labels(uuid,jsonb)` secure staff-only read / settings-permission write RPC.
2. `public.jf_template_tag81(jsonb,text)` compatibility for `Taken By` or `taken_by` in Custom Tag 3.

Both Supabase changes were already applied to the new JioFlow project. Do not rerun migrations.

## Deployment
Review differences against your latest GitHub branch before merging. Use Preview first, then Production.
No frontend deployment has been performed as part of this release.

## Verification
- `node tests-filter-labels.mjs` — passed.
- `node build.mjs` — passed.
- `node tests.mjs` — passed.
- `node tests-upgrade.mjs` — passed.
- Browser UI / live import E2E verification still required.
