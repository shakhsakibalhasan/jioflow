# JioFlow 023 — import, constrained layout editing and interaction polish

## Apply
Apply `supabase/migrations/019_import_notifications.sql` once after migrations 001–018 (the previous Database 022 bundle installs 014–018). Upload the complete source to the existing GitHub repository and let Vercel deploy. This session does not alter your production Supabase schema or main Vercel project.

## Changes
- Customer profile import now saves 100 customers per atomic database request. The 8,673-customer test uses 87 requests instead of 8,673; actual elapsed time depends on database/network performance. There is no new file or total-row cap. Failed/uncertain chunks can be retried; existing phone upserts retain assignment and follow-up history. Progress advances after each confirmed chunk. This remains foreground customer import, not an unattended background worker.
- Retains a first-three-row preview, now clearly labeled “preview”; it is uploaded file data, not seeded demo customer data. Historical invoice imports remain a separate workflow below the customer importer.
- Removes the visible Workspace tools bar. Page actions are in the top three-dot Page options menu. Business operations such as bulk distribution remain available there and through their existing supported controls.
- Edit layout opens an in-page handle editor. Dragging swaps two slots only inside the same parent/grid. Cross-group/free positioning is rejected. Save persists per account/shop/page; Cancel restores original order. Titles/visibility and custom text widgets are available from Page options. Creator platform overview and other supported shell sections also support persistent layout changes; Agents cannot edit layouts.
- Database notifications for email-verification changes, a newly negative follow-up response, and today's leading Agent changing. Top performer is ranked by confirmed-order count, then value, in Bangladesh time. Existing login/reset notifications remain. No notification emails or real courier requests are sent by this update. Previously existing verification states are not retroactively seeded as events.
- Explicit Active/Inactive account badge in account lists; team badges include actual profile activation. Active means account enabled, not proof the person is currently online. Login approval remains separate.
- Sign out opens a confirmation dialog. Browser close/reload uses native beforeunload protection while signed in; browsers control whether and how that prompt appears.
- Refresh icon rotates while refreshing. Interactive controls have a very small press response, with reduced-motion support.
- New Order has a structured courier overview above the form. Entering a valid phone automatically checks the app's available saved parcel history. Provider cards support external result shapes, but the shipped connector has no external merchant credentials/APIs: it explicitly displays Not connected. Local parcel counts, if present, are labeled this business's saved parcels only. No universal courier history or zero-success figures are fabricated.

## Domain readiness
The source builds and local checks pass. A custom domain can be connected after deploying source and applying SQL. Production readiness still requires verification on the actual domain: login, account actions, save/import and email reset links. Courier functionality stays deferred; no real API booking/tracking/history acceptance test was performed.

1. Vercel project → Settings → Domains: add the chosen primary domain.
2. Namecheap → Advanced DNS: add exactly the A/CNAME records Vercel shows for that domain. Keep existing email/DKIM/SPF records.
3. Production environment variable `JIOFLOW_APP_ORIGIN` must equal the primary origin, e.g. `https://jioflowbd.com` (no trailing slash). Redeploy after changing environment variables.
4. Supabase → Authentication → URL Configuration: set Site URL to the primary domain and allow its exact root redirect, e.g. `https://jioflowbd.com/`. Keep the existing Supabase project URL/key in code; buying a Supabase custom API domain is not required.
5. Choose one primary hostname, redirect www/non-www consistently, then test login and reset/verification emails from that hostname.

Official references:
- https://vercel.com/docs/domains/working-with-domains/add-a-domain
- https://supabase.com/docs/guides/auth/redirect-urls

## Courier API next
- Pathao: merchant panel → Developer API. Obtain merchant-approved documentation and credentials from that panel: https://help.pathao.com/integrate-pathao-panel-with-website/
- Steadfast: request/enable merchant API access through the merchant account/support; official integration information: https://steadfast.com.bd/business
- Booking/tracking credentials do not establish that a phone-wide historical lookup endpoint is available. Confirm the phone-history endpoint and its coverage/terms from the provider documentation. A multi-courier history service may use a separate API.
- Credentials will be configured in the server environment/secure server storage during integration. They must not be placed in static browser code or committed to GitHub.

## Validation
Build, 16 focused test files, in-memory SQL migrations 001–019, batch limits and rollback, notification events, permission/tenant checks, slot swap/cross-group rejection/Cancel, courier UI/normalization/escaping and logout confirmation tests passed. Browser QA with synthetic data verified three-dot menu, constrained slot drag and persistence through rerender. Main-domain settings, production data and real provider services were not changed or verified by these local checks.
