JioFlow Update 147 - MM/DD/YYYY import date fix

1. Run Database147.sql in Supabase SQL Editor after your current setup.
2. Replace only historical-import.mjs in GitHub, redeploy, then hard refresh.
3. Database147.sql repairs the first 500 queued old dates automatically.
   If remaining is greater than 0, run Repair_Old_Dates147.sql repeatedly until remaining is 0.
   If a repair batch times out, change 500 to 100 and retry. No CSV reupload is required.

MM/DD/YYYY dates with time (including AM/PM) now parse correctly.
Example: 11/27/2025 14:13 becomes 2025-11-27.
Valid older years are accepted. Blank or invalid source dates remain unknown.
Raw source datetime is preserved. Statuses and customer/order payloads are not rewritten.
This patch is separate from the Update 146 import speed patch.

Validation: local frontend date checks, database date repair, Owner/Agent full and fast date filters,
access checks and build checks passed. Not applied to your live site/database.
