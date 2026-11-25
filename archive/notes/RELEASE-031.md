# JioFlow 031 — Agent drill-down and supervisor dashboards

Includes the full 030 source. Apply JioFlow-Database-031.sql (migration 024) after Database 030 / migration 023.

- Every Agent row has clickable workload/order numbers, sales value and purchase rate. Completed, Pending/Incomplete, cancelled follow-ups and cancelled orders are separate, clearly labelled filters. Names, User Code and email are shown.
- Full report and View Dashboard open only the selected Agent in the current shop. View Dashboard is also available on manageable Agent rows under Account Access/Agents. Creator entering from all businesses switches into the relevant shop.
- Supervisor dashboards show matching KPI cards, percentages, simple progress bars, customer/order switches, status tabs, searchable paged records and latest 30 recorded follow-up/order actions. Each number/bar drills into corresponding records with the same Agent filter.
- Customer details open without impersonating the Agent or exposing edit/password actions. The signed-in supervisor identity remains visible. No simulated live screen, online presence or fabricated activity is shown.
- Customer totals describe current assignments; order and activity totals use selected dates. Imported historical orders use the same normalized statuses and deduplication as the unified order lists.
- Flat cards, subtle brand borders and shared theme/spacing; no 3D/shadow styling. No previous-period comparison is invented.
- Server guard requires current shop management rights: Creator, Owner, or Admin with users permission. Agents and other-business staff are denied. Existing row policies remain active.

Local validation includes supervisor/Agent/tenant permission checks, counts matching paged filters, UI drill-down and production build. Main-site deployment and real shop records still require verification after upload.
