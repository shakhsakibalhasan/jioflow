# Update 63 — Account email clarity and verification confirmation

Requires application Update 62. No SQL migration.

1. Replace application files from this ZIP at matching repository paths and commit to Vercel.
2. Supabase > Authentication > Email Templates: replace Invite user body with Email63-Invite-User.html; Change email address with Email63-Change-Email.html; Confirm signup with Email63-Confirm-Signup.html; Reset password with Email63-Reset-Password.html. Copy file HTML into the template editor, do not upload templates to public hosting.
3. Authentication > URL Configuration: Site URL https://www.jioflowbd.com and permit https://www.jioflowbd.com/ as a redirect. Keep other legitimate existing redirects.
4. Disable email link tracking in the sending service if enabled. Send a fresh verification after deployment/template changes. Existing expired/used links cannot be repaired.

The email opens a landing screen and does not consume its token until Confirm email is pressed. The token stays in the URL fragment until read, then the URL is cleared. This prevents ordinary email URL-prefetch from consuming the provider verification URL. Security software that actively submits forms may still consume tokens. Never share verification URLs.

Account tables now show current login email and explicit Pending new email. Editor explains the same current/pending distinction. Login email remains current until provider confirmation completes. With Secure Email Change enabled, both current and new inboxes must confirm. Do not disable this security control as a workaround.

Expired/used provider errors now explain verification recovery, rather than always asking for a password reset. First-of-two email confirmations supported without falsely logging in. Invitations/recovery continue to password setup; confirmed address changes/signups return to login.

Tested locally: parser, explicit POST verification, partial confirmation handling, account actions, account service email controls, notifications and production build. Real SMTP delivery and Supabase templates have not been changed or tested on production. The screenshot proves provider rejection but cannot distinguish expiration, reuse, stale links or scanning without Auth logs.
