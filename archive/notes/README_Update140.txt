JioFlow Update 140 — Centered login approval and inline login errors

Requires code through Update 138. Update 139 SQL is independent of this UI patch.
Replace online.js and workspace-design.css in the repository.
No SQL is needed. Wait for deployment Ready, then hard-refresh.

Approval screen:
- Centered compact white card with shield, business name and device/account info.
- Soft waiting status, automatic approval polling retained, Check Again, Sign Out.
- Declined/ended state messaging and responsive mobile layout.

Login:
- Red inline error, soft red input background and red border.
- Invalid email format marks email only; missing/short password marks password.
- Server invalid-credentials responses cannot identify which credential was wrong;
  both email/password are highlighted with the existing combined message.
- Typed credentials remain available for correction. Editing clears that input's
  invalid marker. Network errors do not mark credentials invalid.
- No credential-checking permissions or authentication rules were changed.

Validation: syntax, DOM interaction checks, email validation, build and module
resolution passed. Browser screenshot QA could not run in this environment;
no live deployment or authentication check has been performed by the assistant.
