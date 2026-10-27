# JioFlow Update57 — Pathao + API credentials for every new courier

Apply after Update56. Changed files only. No production credentials are included.

## Install
1. In Supabase SQL Editor, run `Database57.sql` once (migration 039). Database56 must already be applied.
2. Upload ALL ZIP files to the same repository paths and commit together. Include `server/pathao-provider.mjs`, `server/steadfast-service.mjs`, `server/courier-secrets.mjs` and `api/steadfast.mjs` — uploading browser files alone cannot enable Pathao.
3. Let your existing Vercel deployment finish, then refresh the CRM.
4. Keep the existing Supabase URL/publishable/secret configuration, app origin and courier encryption key unchanged. No Pathao keys need to be put in Vercel.

## Connect Pathao in JioFlow
Courier → Delivery methods → Add Courier:
- Name: for example, Ecory Pathao.
- Courier type: Pathao.
- Client ID and Client Secret: from Pathao Developer API.
- Pathao merchant email and password: the merchant account corresponding to those credentials.
- Environment: Production for real business orders. Sandbox uses the separate test environment/accounts.
- Store ID: the active Pathao pickup Store ID for this business.
- Default parcel weight: 0.5–10 kg. Delivery: Normal or On demand. Item type: Parcel or Document.
- Keep Active on. Save, then click Check Connection. It authenticates and verifies the configured Store ID is active in that account; it does not book a parcel.
- After verification, Edit, leave credentials blank, enable live parcel booking, Save. Preferred/default is optional.
- To replace credentials on an existing method, enter all four credential fields together. If it has open shipments, add a new method instead, preserving old parcel tracking.
- Existing manually added Pathao entries remain manual. Add a separate Pathao API method; do not assume the old manual entry was converted.

## Booking / tracking
- The existing New Order / Follow-up → New Order flow uses the same selected method for Owner, Admin and permitted Agents.
- Selecting a verified booking-enabled Pathao method enables Confirm & Book. Credentials and token refresh stay on the server and are encrypted per shop and method.
- Name/address/whole-taka COD are checked. COD subtracts pending/verified recorded advance. Address city/zone/area are omitted so Pathao can resolve the full address, as allowed by your supplied guide.
- Each CRM order creates one parcel. Product quantities are sent in the optional item description, not treated as multiple parcels.
- The Consignment ID and order status are saved. Order details → Refresh courier status checks Pathao. If your existing scheduled polling is enabled, it now handles saved Pathao parcels too; no webhook is changed.
- If Pathao booking times out or returns an uncertain response, no automatic second booking is allowed. Owner/authorized staff can use Match & attach parcel in order details, entering the Consignment ID from Pathao. The backend verifies it matches this saved invoice before attaching it.
- Definitive credential/validation rejections can be corrected and retried. Already booked orders return the existing shipment. Unknown provider status labels are shown while keeping the previous CRM status; older pending updates do not regress a final delivery state.

## Phone history limitation
The supplied Pathao Merchant Developer API HTML documents OAuth, stores, booking, price and parcel tracking. It does NOT document a phone-based customer-history endpoint. No private/undocumented endpoint or invented count is used.
A verified active Pathao connection appears as a Pathao-branded history card with unavailable counts and an explicit History API unavailable message. Full all-merchant phone history is NOT connected by this update; it needs separate supported API documentation/access. Tracking a JioFlow parcel is connected and is a different operation.

## Any other new courier
- Typing Carrybee, REDX, Paperfly, Sundarban or any new name keeps API fields visible.
- API Key, Secret, optional Bearer Token and optional HTTPS API base URL can be saved encrypted. Supply at least one credential; blank credentials on Edit preserve existing ones.
- These methods show Setup pending. They cannot be made preferred or book/track parcels until a provider-specific backend adapter is added. They do not produce fake history boxes or claim a verified connection.
- Other courier credentials are not sent to arbitrary entered URLs by this update. Backend work remains necessary before that courier can work.

## Verification
Passed local server/DOM tests for encrypted credentials and token persistence, active-store checks, Pathao booking/sync, duplicate and timeout protection, invoice matching, generic API setup, masked metadata, Agent checkout parity and Steadfast regression paths. All migrations through039 executed in a local PostgreSQL-compatible database, including tenant/anonymous/unauthorized writes, custom-provider booking denial and status non-regression. Setup form visually checked in a local browser fixture.
No real merchant credentials were used, no production/sandbox parcel was created, and no live SQL or Vercel deployment was performed. Run Check Connection after installation to verify your actual account.
