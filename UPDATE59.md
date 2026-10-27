# Update 59 — Unified courier setup, logo color and booking dropdown
Apply AFTER Update 58. Run Database59.sql once in the same Supabase project's SQL Editor. Upload the other files from this ZIP into their existing repository paths, commit, and allow Vercel to rebuild. No new hosting environment variables are needed. This package has not been applied to your live Supabase project or Vercel deployment.

## Delivered
- Shared courier catalog and connection form. Provider-specific fields appear for Steadfast, Pathao, CarryBee, REDX, Paperfly, eCourier, Sundarban and Other. Saved credentials remain encrypted and masked; changing branding does not replace them.
- Uploaded logos determine the header's dominant brand color, ignoring white/transparent background. Logo sits inside a white pill sized to its own aspect ratio with padding. There is no automatic/default courier logo. Manual color override is available. Monochrome logos use their neutral pigment; all-white images retain the current color.
- Booking dropdowns show ONLY active, verified, booking-enabled installed API connections from the current shop. No hardcoded Pathao/Other options or environment-only fallbacks appear. An empty list disables booking. Shared Owner/Admin/Agent New Order and saved-order selector use the same filter.
- Connection list separates booking/tracking readiness and history access testing.
- Native eCourier adapter added using its published General API v5.5: assigned package check, COD booking, tracking/polling, customer fraud status, and safe reconciliation of uncertain bookings. Enter API Key, API Secret, USER-ID and assigned package code. No merchant password is requested for eCourier.
- eCourier delivery requires city, thana, area and postcode in New Order or the saved-order booking form. Its published address limit is 40 characters; COD must be a positive whole-taka amount. Saved order values determine name, phone, COD and reference. Exchange sending type is mapped. Ambiguous booking failures cannot be blindly retried.

## Capability status — do not confuse saved keys with a live integration
| Courier | Booking/tracking adapter | Phone result |
| --- | --- | --- |
| Steadfast | Implemented previously | Courier-supplied history/rate; missing counts remain unavailable |
| Pathao | Implemented previously | Native success-rate lookup attempted with account permission |
| eCourier | Added here | Published API provides customer/fraud status, NOT exact delivered/cancelled totals |
| CarryBee, REDX, Paperfly, Sundarban | NOT implemented/verified in this package | NOT implemented |

The last four couriers can retain encrypted connection information but are excluded from live booking and phone-history cards. Full official endpoint/auth/payload contracts were not available from the public material retrieved this session; they are still outstanding work. This update does NOT complete all-courier live booking/history. No merchant account's production credentials were used, no actual parcel was booked, and live account permission remains to be tested.

## References and validation
Official eCourier API General v5.5: https://ecourier.com.bd/wp-content/uploads/eCourier_Merchant_API_Document_General_v5.5.pdf
Official resources page: https://ecourier.com.bd/resources/
Other provider field presets are credential storage conveniences, not claims that all credentials or endpoints are verified.

Checks: synthetic provider authentication, assigned-package validation, booking idempotency, ambiguous outcome handling, tracking, history caching, nullable counts, encrypted credential preservation, tenant isolation, service-only status writes, terminal-state preservation, PostgreSQL migrations through 041, shared UI, dropdown exclusions, pixel color selection/manual override, logo preview and browser rendering. Live merchant API responses are not verified.
