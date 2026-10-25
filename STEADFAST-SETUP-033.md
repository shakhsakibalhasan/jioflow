# JioFlow Update 033 — Courier setup inside the software

This supersedes the per-courier environment-variable setup in Update 032. EcomDrive's existing webhook remains untouched.

## Install once

1. Upload the complete Update 033 source ZIP to the existing GitHub repository root, preserving all folders. It includes previous updates.
2. In the existing Supabase SQL Editor, run `JioFlow-Database-033.sql` once AFTER Database 032. If 032 has not been applied, apply the included `JioFlow-Database-032.sql` first (032 itself requires Database 031). Do not rerun SQL files already applied.
3. Allow Vercel to deploy the commit. The existing account-service server configuration must remain: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY` (or legacy `SUPABASE_SERVICE_ROLE_KEY`) and `JIOFLOW_APP_ORIGIN`.
4. Keep `api/` and `server/` in the repository. A static `dist/`-only upload cannot save encrypted credentials or book parcels.

## Add a courier without editing hosting settings

1. Login as Creator or the shop's Owner. An Admin needs the Integration permission.
2. Select the business, then open Settings or Courier -> Delivery methods.
3. Click Add Courier. Enter a method name, select Steadfast, and privately enter that business profile's API Key and API Secret.
4. Choose Active and, optionally, Preferred / default. Set the default shipping note and whether product names should be sent.
5. Leave Enable live parcel booking off until you finish merchant verification and are ready for a real booking.
6. Click Save courier. Additional courier accounts can be added the same way; no new environment variable or source edit is needed for each supported account.
7. Existing keys are never sent back to the browser. Edit lets you replace both keys or leave both blank to keep them. Show entered keys only reveals values you are currently entering.
8. Check Connection is optional and explicit: it checks credentials without booking a parcel. Do this at the end, as requested. A failed check or ownership hold must be resolved with the merchant account before live booking.

The supported provider in this release is Steadfast. Pathao, RedX and other providers need their own documented API adapter before they can be selected; their names or empty cards are not shown as working integrations.

## Customer history

* The history strip is hidden when the phone is empty or incomplete.
* A valid phone automatically loads Our Record, Overall and the connected courier result, above the customer fields. Clearing the number hides it again.
* Only available connected providers appear. No permanent Pathao / Steadfast placeholder cards.
* Our Record covers visible live and imported orders in the current shop, deduplicated by order number. Its details link opens customer/order history; Autofill fills empty customer fields without overwriting manual entries.
* Overall combines available provider counts. Supplier rates cover finished parcels; pending parcels are excluded. Missing history/rates show a dash, never a fabricated safe score.
* New Order lists active delivery methods by their saved name and preserves the selected method with the saved order. Confirm & Book requires the selected method's live-booking switch and the user's booking permission.

## Permissions and existing shipments

Creator / Owner and Admins with Integration permission can manage the current shop's methods. Agents can use active methods but cannot manage or read the stored keys. Shop/session and order permissions are checked server-side.

Methods can be made inactive, set as preferred, edited or removed. Removing a method hides it from new orders; its encrypted credentials are retained for existing parcel tracking. A method with open shipments cannot have its keys replaced with a different account: add another method for new shipments instead. Naming, notes and activation can still be edited.

Old shipments booked through the previous environment-based setup continue using those previous credentials until settled. Do not remove those legacy environment keys while such parcels remain open.

## Scheduled status updates

The existing GitHub Actions polling workflow and its two secrets remain unchanged. This is one-time scheduler infrastructure, not a per-courier setup:

* `JIOFLOW_POLL_SECRET` must match between Vercel and GitHub Actions.
* GitHub's `JIOFLOW_POLL_URL` points to your production `/api/steadfast-poll` endpoint.
* Enable `JIOFLOW_POLL_ENABLED` in Vercel and the repository variable only after the final manual test.

New in-app bookings preserve their delivery-method ID so status polling uses the correct account, including after a method is made inactive. EcomDrive's webhook URL and token are never changed by this code.

## Secret storage / operator note

Credentials use AES-256-GCM authenticated encryption, with each payload bound to its shop and method ID. Browser roles cannot read the credential table or its service-only RPC. Metadata responses exclude the ciphertext. No courier credentials are stored in local/session storage or the static build.

By default the encryption root is derived from the existing server-only Supabase credential, so no additional hosting key is required for initial setup. A separate stable `JIOFLOW_COURIER_ENCRYPTION_KEY` can optionally be configured before storing any keys. Preserve the encryption root and plan re-encryption before rotating it or the server credential used as its fallback; changing it without migration makes earlier encrypted credentials unreadable.

Prepared and tested locally with synthetic records only. This package does not apply production SQL, change deployment settings, connect real keys, verify merchant ownership or book live parcels by itself.
