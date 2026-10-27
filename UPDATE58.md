# Update 58 — Courier branding and history settings
Apply after Update 57. First run Database58.sql once in the same Supabase project, then upload the remaining changed files to the existing repository and commit. Vercel builds the application normally. No environment-variable changes are required.

Couriers → delivery methods → Edit:
- History settings: enable/disable customer-history lookup and test a saved, verified connection with a phone number.
- Upload a PNG/JPEG/WebP logo (up to 250 KB), preview it, choose a brand color or remove the logo. No automatic/default courier image is selected.
- Saved nonsecret details, merchant email, connection options, logo and history switch remain visible. Saved secrets are masked; ordinary edits preserve the encrypted credentials. Select Change saved credentials only when replacing them.
- Pathao initially uses merchant email/password with client ID/secret to issue its token; subsequent refresh uses the saved refresh token automatically.

The native Pathao POST /aladdin/api/v1/user/success-rate phone lookup is now attempted for verified production connections with history enabled. This endpoint is documented by a published integration developer (https://wordpress.org/plugins/advance-fake-order-protector/); it was not included in the uploaded merchant guide. Actual account permission and live response remain unverified. A returned rating is displayed as a rating, never translated into invented counts. Unknown payloads or denied access show an unavailable state.

Steadfast's returned success percentage is separate from exact parcel counts. Missing delivered/cancelled values remain unavailable, not zero. Saving API keys alone cannot grant an unavailable courier history capability. Custom courier credentials can be retained, but their provider adapter must be implemented before lookup/booking works.

Verified with synthetic fixtures: metadata/credential preservation, image preview/removal, history switch, native Pathao request and parsing, cached lookup, existing booking/tracking/auth tests, and database migration/security tests. No real booking or production merchant history test was made.
