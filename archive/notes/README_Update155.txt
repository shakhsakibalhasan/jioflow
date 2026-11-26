JioFlow Update155 - Three dashboard counters, completion and layout fixes

INSTALL AFTER UPDATE154:
1. Run Database155.sql in Supabase SQL Editor. Earlier Database149 and Database152 must already be applied.
2. Replace ALL NINE application/style files from this ZIP in GitHub, deploy and hard refresh:
   workspace-tools.mjs, record-panel.mjs, agent-reports.mjs, online-client.mjs,
   agent-workspace.mjs, original-sections.mjs, record-cache.mjs, online.js, workspace-design.css
Do not upload the README/AUDIT as code. No build configuration or courier files are replaced.

COUNTERS:
Confirmed Customers: current active customer workflow has a Confirm-type status. No order is required. Moving to another status removes the customer from this count.
Orders Created: native saved order records (including Save Order drafts and Confirm & Book-created orders), excluding archived records. One order counts once. Imported historical rows are not counted as newly created native orders.
Booked: native orders with a successfully recorded courier booking (shipment.booked_at exists), counted once per order. A pending/failed booking with no successful timestamp does not count. Later delivery/return progression does not remove the successful-booking count.
Order counters use the selected order-created date period. Confirmed/Completed customer totals describe current customer workflow, matching the customer-list model. Existing list filters can narrow customer cards using returned panel counts.
The three cards appear in shared Dashboard/Follow-up customer summary screens. Agent Reports use the same three definitions. Clicking Booked opens successfully booked orders, including those whose delivery status has advanced.

COMPLETED:
Every explicit status save counts as Completed even if it is Processing or has no call response. The same customer is counted once. Pending is the complementary unfinished group.
Callback timing, Agent workflow labels, imported statuses and native order statuses are preserved.
Previously pending/no-response rows are repaired only where a recorded explicit follow-up interaction exists. Untouched imported/default customers are not marked Completed.

CHECKS:
Real local database suite passed: migration twice, Confirm/list/report agreement, explicit Processing completion, repeat updates, order count, pending booking exclusion, successful booking inclusion, later Delivered preservation, booked drilldown, touch-only sync suppression and Agent/shop access controls.
DOM/integration checks passed for the three cards, saved layout IDs, layout exposed before slow totals, old-summary overwrite prevention and Booked routing. Status, bulk-unassign, search, cache, layout, client and build regressions passed.
No live production application, production query-plan inspection or real-browser visual/latency measurement has been performed. This fixes the documented findings; it does not certify that every possible site bug is absent.
