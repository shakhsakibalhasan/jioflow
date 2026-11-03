Update 92 - Restore and merge imported customers
Requires Database89.sql already applied.
Run Database92.sql in Supabase SQL Editor. No frontend replacement needed if Update 91 is installed.
Then choose the original file again and click Import. Previously rejected payloads were discarded, so the failed job cannot replay those rows.
Only customers matched by normalized phone in the importing shop are restored during a successful import. No blanket restore occurs when applying this SQL. Same phone keeps one customer/follow-up; separate Order IDs retain separate dated history, and repeated Order IDs update the existing history.
Public customer editing and Agent access are unchanged. Imports retain staff/import/assign permission checks.
Local database tests passed: normalized phone merge, archived restoration, repeated Order ID update, separate orders, failed-row rollback, private helper access denial, migration applied twice. No live deployment or production data changes performed.
Latest-order display/date sorting is unchanged by this patch.
