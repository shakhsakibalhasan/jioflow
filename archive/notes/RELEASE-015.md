JioFlow update 015 — account visibility and recovery

Apply migrations through 011 first, then run supabase/migrations/012_account_recovery.sql once. Upload the extracted package contents to the existing GitHub repository root, replace matching files, commit and let Vercel redeploy.

Root cause found in the code: shop deletion intentionally preserves Auth identities and inactive user profiles, but deleting the shop removes their Owner/membership assignment. Account Access previously grouped only Owner/Admin/Agent, so profiles whose current role was Unassigned were omitted. Removed profiles and Auth users without CRM profiles can also reserve an email while being absent from the normal list. A generic conflict message previously combined duplicate email and occupied Owner assignment errors.

Changes:
- Account Access, with All Shops selected, now shows an Unassigned accounts group when such profiles exist. Creator can edit/activate/remove them through the existing controls.
- Creator sees Find account in Account Access and staff account sections; Add Account also offers Find existing account. Lookup checks the actual Auth identity, profile, activation, email verification and current business assignment. No password, hash, reset token or service credential is returned.
- An unassigned, removed or missing-profile account can be restored explicitly: Find account → enter its email → choose business and role → confirm reactivation → Restore account. The existing Auth user ID is reused; its password and email verification are not changed. Role assignment and activation happen in one database transaction. Existing sessions are revoked by the role assignment logic.
- An already assigned account is directed to normal Edit / Activate controls rather than silently moved. Creator self-recovery is forbidden. Managed Agents cannot be promoted to Owner/Admin using internal email confirmation.
- Creator Add Account preflights existing emails. Conflict messages distinguish duplicate emails from an already occupied Owner slot.

For the reported Owner login: after applying the update, use All Shops → Account Access → Find account. If unassigned/missing/removed, restore to the intended business as Owner. Then sign in using the existing account password. A password typed into a failed Add Account request never replaced the previous password. If email verification is pending, complete the verification; if the password is forgotten, use email recovery after restoring the profile. Email delivery must already work for that link.

Local validation covers migrations 001–012, removed Owner restoration, missing-profile repair, occupied-Owner rollback, unchanged password hash, retained verification, new-session access to the restored Owner's shop, role protection, UI confirmation and visible unassigned accounts. Browser review used synthetic data only. The reported production email/account was not inspected or restored remotely; screenshots alone do not establish its exact Auth/profile state.

Existing courier/reporting/import/settings/email-delivery limitations remain as documented in prior releases.
