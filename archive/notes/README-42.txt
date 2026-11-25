JioFlow Update 42 — changed files only, apply after Update 41.
1. Supabase SQL Editor: run Database42.sql (includes migrations 027 and 028). Requires existing migration 026.
2. Upload ALL source files in this ZIP to the same paths in your GitHub repository. Include build.mjs and both new modules. Do not replace your project with only this ZIP.
3. Let Vercel build and deploy. Refresh the browser after deployment.

Changes: restored default Dashboard grid; rounded sidebar buttons; full customer/action pages; Follow-up Eye and Assign actions; editable unbooked order products; shared Agent New Order/phone-triggered courier UI with permission checks; actual layout height/width resizing; Order Date and full-address hover text; imported historical statuses excluded from live Confirmed/Delivered and Agent sales counts. Import preserves manual follow-up outcomes.

Database42.sql does not delete historical data or change manually saved live order statuses.
Verified locally: database migrations 001–028, Agent own-data workflow and UI regression checks. No production SQL, deployment or live courier booking performed.
Courier provider blocking/credentials are not resolved by this UI patch.
