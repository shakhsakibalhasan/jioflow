# JioFlow 024 — direct record panels and customer order summary

Includes all changes in RELEASE-023.md (faster batch import, three-dot menu, constrained layout editing, notifications, activation labels, exit confirmation, motion and courier overview).

## Latest correction
- Dashboard/status boxes navigate to the corresponding full page, with a matching filter. Unassigned opens Follow-ups / Unassigned; order counts open All Orders with their status; financial counts open Profit/Courier as appropriate.
- Record lists no longer open in an All Customers/Orders modal. The existing panel retains its status tabs, search, filters, select/distribute toolbar and edit/follow-up/note actions. Paged records use full-database queries with existing tenant/Agent row policies.
- Agent and top-performer links open the Agent Reports page with the selected Agent, scoped summary and customer/order details. Customer history and individual edit forms can still use dialogs; the change is to summary/list navigation.
- Filter state (status, Agent, source, product, period) is reflected in the route and survives refresh. Search terms are not written into URLs.
- New Order → Order Summary includes customer name, phone, delivery address and area, updated while typing and escaped safely.

## Loading, refresh and appearance
- Temporary connection failures retain the signed-in session; startup offers Retry rather than clearing credentials. Expired or revoked access still requires sign-in.
- Refresh and save reload the current route/business/filter. Stale account-data responses are ignored, and background business counts no longer remount the shop dashboard.
- Centered 72px rotating ring around the stationary JioFlow brandmark replaces the Connecting text; reduced-motion is supported.
- Sidebar Light/Dark controls and seven round palettes (original JioFlow default, Ocean, Violet, Rose, Teal, Amber, Slate). Preferences persist in this browser; palette switching keeps light gradients, semantic status colors and black profit cards.

## Installation
1. The previous Database 022 update (migrations through 018) must already be applied.
2. Apply `JioFlow-Database-024.sql` ONCE. It atomically installs new migrations 019 and 020. If 019 was already applied separately, run only `supabase/migrations/020_direct_record_panels.sql` instead.
3. Upload the complete source to the existing GitHub repository, commit and wait for Vercel to deploy.
4. Check main-domain login, Dashboard → Unassigned navigation, search/next page/select/assign/edit/note, New Order summary, import, logout confirmation and notifications after real events.

## Domain and courier setup
See RELEASE-023.md for the full domain/API guide. In particular: Vercel Domains → domain-specific DNS values → Namecheap; set production `JIOFLOW_APP_ORIGIN` to the primary HTTPS origin with no trailing slash; update Supabase Auth Site URL/redirect allowlist and redeploy. Leave email DNS records intact.

The courier overview is a prepared layout and local-history lookup. External Steadfast/Pathao history/booking/tracking APIs are not connected, and provider coverage must be checked against merchant documentation. API credentials must remain server-side. A successful build/local test is not confirmation that the production domain, email reset links or real courier APIs have been commissioned.

## Validation
Local database migrations and tenant/permission/filter tests, direct record-panel pagination and navigation, Order Summary live updates/escaping, prior import/layout/notification/Auth tests, and build pass. Browser QA with synthetic data verified Dashboard Unassigned opens the Follow-ups page without a list dialog and customer fields update in Order Summary. No production data, domain DNS, credentials or courier parcels were changed.
