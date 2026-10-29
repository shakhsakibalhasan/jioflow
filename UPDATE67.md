# Update 67 — Permissions, follow-up filters, in-place editing and courier branding

Apply on Update 65 or 66. The changed files include the compact phone/editor improvements from 66. No existing account permissions are automatically granted.

## Install
1. Run Database67.sql once in the existing Supabase project's SQL Editor. It requires migrations through 046 (Update 65). The matching migration 047 is included for source-controlled migration workflows; do not apply both copies separately.
2. Replace the files from this ZIP at their existing relative paths, including server/steadfast-service.mjs, the four assets/courier-* images, and the new courier-presets.mjs and page-options.mjs. Commit the changes and let Vercel build.
3. Refresh the application after deployment. Sign in again after changing account permissions; Agent approval and single-device rules still apply. No environment changes are needed for the branding/editor changes.

## Included changes
- Owner/Admin/Creator can select all 15 Agent permission checkboxes. Existing checked defaults and saved permission JSON are preserved. Newly delegated features are checked by the server, not only by the navigation UI. Agents cannot change their own or other accounts' permissions or promote roles. Login approval cannot approve one's own session. Force logout and Agent approval are separate delegated capabilities.
- Advanced Follow-up filters are available to Creator, Owner, Admin and Agent. Agent option lists/results retain their assigned-customer scope, including the three custom tag selectors and existing payment bands starting at 0.
- Repair only malformed, overcrowded saved dashboard KPI rows. Preserve metric values, labels, order and hidden state; no global layout reset.
- Entering Edit keeps the current visual arrangement. Row wrappers are created only when a move/resize/save actually happens. Same-row dragging and arrow-based row changes remain. Save/Cancel are in the existing three-dot menu, not a full-width bar.
- Three-dot page options open a small anchored theme-matched popover, with close/Escape/outside dismissal. Desktop geometry remains unchanged on entry into Edit; compact phone styles are retained.
- Four supplied logo presets: Steadfast, Pathao, CarryBee and REDX. Setup has four quick choices; the existing other/custom courier field remains available so prior connections are not removed. Original image pixels are preserved; SVG view boxes frame their wordmarks. An uploaded replacement logo still takes precedence.
- History cards use each preset's brand strip, white logo badge, faint corner watermark and matching success bar. Booking detail headings and the courier setup list use the same logos. A custom saved brand color takes precedence over the preset.
- Shared courier catalog/server metadata registers preset identity, original logo asset and default color. Only active, verified, booking-enabled installed adapters are offered for booking. Missing history counts display unavailable, not fabricated zero.

## Courier capability boundary
This update does NOT install native CarryBee or REDX booking/tracking/history adapters. Their setup can securely retain the provider's credentials and their branding is ready; saving a token does not mark them verified or booking-ready. They remain out of the booking dropdown until a supported adapter is installed and verified. Existing native Steadfast/Pathao/eCourier integrations are preserved. Cross-merchant phone history depends on a supported history endpoint and the courier account's access; booking credentials alone cannot guarantee it. No real parcel was booked and no production API credentials were used in testing.

## Validation
Local database suite through 047 passed, including unchanged permission defaults, Owner/Admin grant, revocation, self/peer permission escalation rejection, self-approval rejection, cross-business rejection and scoped Agent filters. Account action, Follow-up filter UI, in-place editor/repair, courier overview, courier branding, courier checkout, server encrypted-settings and Steadfast suites passed. Production build and diff whitespace checks passed.

Browser QA: desktop and phone card geometry matched exactly before/after entering Edit, with no initial row wrappers or full-width edit bar. The malformed 17-card row recovered readable widths. The four supplied logos and branded cards were visually checked in a local design fixture. docs/update67-couriers-preview.jpg is a design preview with clearly labelled sample values, not a production courier result. Real CarryBee/REDX operations were not tested. These source changes have not been deployed to the production domain.
