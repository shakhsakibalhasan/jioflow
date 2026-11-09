JioFlow Update 138 — Compact sequential import console

Requires Update 136. Includes the Update 137 sidebar CSS.

1. Run Database138.sql in Supabase SQL Editor.
2. Replace these repository files:
   live-customer-import.mjs
   online-client.mjs
   workspace-design.css
3. Wait for deployment Ready, then hard refresh.

What changed:
- Centered 640px compact console, five fixed columns. Address is truncated with
  full text on hover; status stays visible. Long rejection reasons scroll inside
  their own cell. No horizontal scrolling is needed to find the status column.
- Small colored dot legend and slim brand-color progress bar.
- One saved record per request. Its real server outcome is returned in the same
  response; no extra results query per record and no pending-row preview.
- New result rows append without rebuilding the entire table. Auto-follow stops
  when scrolling back and resumes when scrolled to the bottom.
- Cancel stops after the current record; already committed records remain.
- Done closes the completed import, clears the selected file and working state,
  unlocks the uploader, and keeps a completion summary.
- Existing failed-import Resume stays available.

Local validation:
- SQL applied twice; real PGlite one-row commits and final completion passed.
- DOM checks: only committed rows shown, five columns, counters, Done/reset,
  no redundant results/process calls, cancellation before next row passed.
- Build completed and dependency graph check passed.

Not yet verified in a real browser or against live Supabase. Upload speed still
includes network and database time per record; no artificial delay is added.
The reported CANCEL historical status is not changed by this patch; the source
CSV and corresponding live history still need comparison.
