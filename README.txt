JioFlow Update 101 — CSV dates MM/DD/YYYY

Requires updates 96–100. If Database100.sql was not applied, run the included Database100.sql first.
1. Run Database101.sql in Supabase SQL Editor.
2. Replace historical-import.mjs and record-panel.mjs in the repository root.
3. Deploy, then refresh the browser and apply the Order Date filter again.

CSV numeric Order Date uses MM/DD/YYYY: 09/01/2026 = 1 September; 09/30/2026 = 30 September. ISO YYYY-MM-DD remains supported. Invalid numeric dates reject the import preparation with a clear format message. Blank dates remain blank.
Existing historical rows are read from their original Order Date using MM/DD/YYYY; original CSV values are preserved. No re-upload is required for existing rows with original_columns. This does not recover rows never successfully imported or deduce dates absent from the source.
Shared Owner/Admin/Agent date logic and existing permissions are preserved.
Follow-ups count unique customer phone profiles; this may differ from another software's order count and source/created-date filters.
Local database, CSV/display and build checks passed. Not deployed to the live website.
