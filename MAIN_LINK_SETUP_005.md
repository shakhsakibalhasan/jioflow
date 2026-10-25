# Main workspace update 005

Upload the update files to the existing GitHub repository, replacing files with the same names. Keep existing Vercel environment variables. Wait for the Vercel deployment to finish, then open https://jio-flow.vercel.app/ and refresh.

No new SQL migration is needed for this update; migrations 001–004 must already be applied. Supabase Authentication URL Configuration: keep Site URL https://jio-flow.vercel.app and allow redirect URL https://jio-flow.vercel.app/ . Retain the existing /online.html redirect URL for old invitation/reset links.

The main page now uses Supabase Authentication and existing live account/shop/product/customer/follow-up operations. It does not load the browser-local demo scripts. Existing browser-local records are preserved but are not imported automatically. /online.html is a compatibility redirect to the main page; it preserves email-link tokens for the authentication handler.

This is a staged implementation, not a completed production CRM. Order processing, imports, courier booking/status synchronization, device/session approval, reports, account edit/removal and uploads still need backend integration. Invitation/reset email delivery depends on the deferred SMTP setup. No live account login or email delivery was verified with user credentials.
