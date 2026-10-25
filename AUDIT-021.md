# JioFlow interaction audit — Update 021

## Scope and verification
Source and rendered DOM were inspected with synthetic records. No production records were created, edited or deleted. Automated checks exercise DOM click handlers, reporting transitions, mock shop-scoped queries/RPC saves, and stale-response isolation. This is not a signed-in production acceptance test. Vercel must deploy this source before its main URL changes.

## Fixed in this update
- Restored allowlisted dashboard summary, funnel, source, product and status drill-down actions. Legacy browser-only mutation functions remain blocked.
- Restored Agent full reports and record-filter links, plus report search and status selection.
- Restored follow-up status chart actions, call filters, filter reset, and source-chart selection.
- Added read-only details for summary cards that lack a dedicated filter action.
- Connected profit breakdown links to matching loaded orders by source, product or Agent; COD link opens delivered records, not a courier settlement reconciliation.
- Connected customer links and follow-up note buttons to real customer history / follow-up forms.
- Customer history has Edit customer and Record follow-up buttons for permitted users.
- Order details, shipping note and assignment editor are now reachable from dashboard, reports and profit screens, not only All Orders. Existing order status restrictions still apply.
- Product/customer edit waits for its real action provider to load. Records absent from the hidden provider's first page are fetched individually with a shop filter. Late responses do not open an editor after navigation/logout.
- Creator's user Edit & permissions link opens the existing real account editor rather than a disabled local preview.
- Action failures are shown in the visible workspace instead of only a hidden operations region.

## Still incomplete / not enabled
| Area | Remaining work |
|---|---|
| Global page editor | Persistent layout editing, add/delete/reorder widgets, show/hide sections, page titles and layout reset. The legacy menu remains disabled. |
| Customer distribution | Bulk selection, group assignment/unassignment, group management and Agent Take More Orders. Individual customer assignment remains available in Edit Customer. |
| Product bulk tools | Activate/deactivate selected products and row Archive. Individual activation/edit works; Creator Manage records can archive/restore. |
| Workflow labels/tags | Custom follow-up statuses, tags and return reasons are not persisted by the retained settings screen. Current follow-up save supports pending/callback/completed/cancelled. |
| Settings | Retained business/account/money/workflow/schedule/Hero forms and add/edit/remove options are not connected to durable saves. Use the separate real Shop Edit, Account Access and My Profile editors for their supported fields. |
| Courier | Provider API settings, phone history check, booking, bulk booking, automatic tracking, cancellations and settlement/COD reconciliation need backend integration. Save Order works; Confirm & Book is intentionally unavailable. |
| Profit | Order fee/cost editing and complete courier settlement accounting remain disconnected. Missing costs must not be treated as verified profit. |
| Import | Customer CSV/XLSX import works; historical order import, background processing and resumable large jobs are not implemented. |
| Reporting | Retained reports and their new drill-downs use loaded records (typically newest 50), not whole-database aggregates. Some retained labels/status semantics and percentages still need alignment with production follow-up outcomes. |
| Management permissions | Creator management and self-profile editors exist. Owner/Admin delegated editing of other accounts is still restricted by existing account-management authorization; this update does not bypass it. |

## Existing functionality retained, not newly verified against production
Login and session gate; self-profile/password flow; Creator account controls; shop edit/pause/delete; product add/edit/images; customer add/edit/follow-up; order entry and pre-booking order edits; customer CSV/XLSX upload/import. Availability depends on installed SQL/API updates, role permissions and backend configuration.

## Acceptance checks after deployment
1. Open a shop Dashboard and click Confirmed, Completed and Unassigned. Confirm matching loaded records appear.
2. Open a customer → Edit customer → save a reversible detail; refresh and verify persistence.
3. Open a product → Edit → save; verify Active/Inactive persists.
4. Open All Orders → order details → update a permitted pre-booking status/note; refresh.
5. Open Agent Reports → Agent → status totals → matching customers/orders.
6. Repeat with an Agent account and confirm restricted financial/account-management actions remain unavailable.
