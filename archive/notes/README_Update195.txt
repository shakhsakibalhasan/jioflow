JioFlow Update 195

1. Run Database195.sql once in Supabase SQL Editor after the earlier updates through 193.
2. Replace included site files, rebuild/redeploy, then reload.

Pending / Incomplete report numbers are red; Completed numbers are green, including total rows and group member reports.
Returning a customer to Processing reopens it, removes it from both Completed views, and updates dashboard/report counts.
A member can belong to only one group. The picker excludes members of other groups; database and save API also enforce the rule.
Existing duplicate links: oldest active group is retained (oldest group if none active). Extra links are preserved privately in group_links_backup195 before removal. Customer assignments and order history are not deleted.
No production changes have been executed by this patch.
