# JioFlow Update 55
Changed files after Update54. Apply on top of Update54, not as a full new project.

1. Back up the existing Supabase project, then run Database55.sql in SQL Editor. This adds a separate table/RPC for manual courier names and logos. Existing API secrets, customers and orders are not changed. Requires previous database updates through Update54.
2. Replace the included application files in the GitHub repository root, commit and redeploy Vercel. No new environment key is required for these changes.
3. In an approved Agent account, open Follow-ups > View. Add products, edit/save customer information if needed and enter payment details. Create Order must open the existing New Order (#new) page with those values; it must not save an order or book a parcel. Confirm only there.

Order handoff: Create Order now transfers an unsaved form, not a database draft. It restores customer name/phone/address/area, source, products, quantities/prices, discount, delivery charge, advance, payment reference and delivery note on the existing New Order page. Data is scoped to the account/business, stored in the tab session for up to one hour, and cleared on successful submission or logout. A missing/expired/wrong-shop handoff is rejected. Existing server permissions and product validation apply at final confirmation.

Product UI: one shared catalog/cart renderer across Follow-up, New Order and saved-order details (including read-only orders). Compact thumbnails, name, unit price, line amount, quantity stepper and remove control. Price/discount access stays permission-controlled. Saved-order product thumbnails are fetched within the same shop.

Roles: Agent follow-up row has View text only, without assignment. Owner/Admin/Creator retain Eye and Assign. The full customer details/status/product page remains available. Name and number have clearer weight, the customer header is refined, and authenticated pages share a centered maximum width with responsive side spacing. Existing color theme is retained.

Notifications: opening the bell marks only currently displayed unread notifications as read. Other shops/undisplayed notifications are not marked by this action. Existing mark-all/delete options remain.

Courier setup: type the courier name (Pathao, Carrybee, Sundarban or another) and optionally upload a PNG/JPEG/WebP logo. These are MANUAL delivery methods. They can be selected when confirming an order, which is then booked directly with that courier outside JioFlow; the button explicitly says Confirm Order. Automatic API booking/history for these providers is NOT implemented by naming them or uploading a logo. Steadfast's existing API configuration remains unchanged. Manual courier Order details explicitly indicate manual processing.

History boxes: ONLY API-connected providers appear. A manual courier or a provider without an API connection is hidden in the history strip. Connected providers use the same styled box system, with supplied logo metadata (Steadfast retains its existing logo). An API error retains unavailable values, never invented zero counts. Blank phone still hides the strip.

Validation: mocked end-to-end Follow-up to existing New Order, no premature order write, exact final payload, account/shop isolation and logout cleanup; all-role cart parity; Eye/Assign role controls; bell read scope; typed manual courier/logo settings and manual confirmation without false API calls; full PostgreSQL-compatible migration/security suite including manual courier create/remove and cross-tenant/anonymous denial; existing order editor, courier history/methods, notification and workspace integration checks. Desktop New Order preview inspected with sample data for centered layout, catalog and cart. Browser visuals for every page/mobile and live provider operation are not verified. No live SQL, deployment, real order or parcel booking performed.
