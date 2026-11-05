JioFlow Update 104 — fix missing date/amount in unfiltered All list

Requires Database102.sql and Database103.sql.
Run Database104.sql in Supabase SQL Editor, then refresh the website (Ctrl+Shift+R). No frontend replacement is required.
If the SQL reports the prerequisite error, apply Database102.sql and Database103.sql before retrying.

Confirmed defect: the staff fast-list function had a separate unfiltered All shortcut, returning customer/follow-up fields without order_date, order_amount or latest_order_status. Updates 102–103 corrected the date-filtered query but this shortcut still bypassed it. Reproduced locally with status=all and no advanced filters: all three fields were absent.

Fix: route the staff fast list through the existing indexed batch projection with _fast=true. It now includes matching order date, amount and latest status while deferring full tab counts. Existing staff authorization is retained; Agent routing remains scoped to assigned records.

Validation: unfiltered All, search, Assigned, full/fast field consistency, Owner/Admin/Agent, chronological order, repeated SQL application and cross-shop denial. 3,500-row local All-list fixture also checked. Dates/amounts missing from the source are not invented.
Not applied to production.
