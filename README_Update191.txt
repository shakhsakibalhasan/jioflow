JioFlow Update 191 — Agent actions, device removal, create completion and login email

Apply after Update190 (and Database189).
1. Run Database191.sql in Supabase SQL Editor first.
2. Replace the included root files and preserve api/ and server/ folder paths.
   Deploy the full application normally, then hard-refresh your browser.
   Do not deploy server modules as publicly served static files.
No live deployment, live user creation or production SQL execution was performed here.

Changes:
- Original Users & groups Remove and Activate/Deactivate controls now map to the guarded
  real account functions instead of disabled prototype actions. Owner/Creator and the
  existing authorized Admin hierarchy apply; Agents cannot remove themselves or staff.
  Remove uses the existing confirmation flow. Customer/order history is preserved under
  existing account-removal rules; account removal clears current assignments.
- Device cards offer Remove device for authorized managers. Confirmation revokes that
  JioFlow session and hides its card. A future login requires a fresh approval.
  Hidden history is retained in the database/audit, not permanently erased.
- One approved Agent session per Agent is now enforced by a unique database index.
  Existing approval code already locks the Agent profile and revokes previous sessions.
  The new index also blocks duplicate approvals at the database level. Any legacy duplicate
  approvals are revoked before adding the index. Pending requests cannot work in the app.
  Multiple historical/revoked device cards do not mean multiple active logins.
- Add user continues to create a managed Agent through the real account API. A successful
  response must include the created user ID. The popup closes without waiting for the slow
  directory reload. The list refresh runs separately. A failed creation keeps the popup open
  and shows its error. Do not resubmit a created account just because the list refresh is slow.
- Existing server account files are included so the managed-Agent endpoint is present in
  the deployment. Existing server environment keys and allowed origin must still be valid.

Validation:
- Database191 applied twice on a local database snapshot, including a legacy duplicate
  approved-session fixture: duplicate cleanup and one-approved-session invariant passed.
- Approving a new login revokes old app access; device removal hides/audits/revokes its
  session; self-removal and anonymous calls denied.
- Actual database prepare/finish Agent creation, deactivate/activate/remove passed.
  Hosted Auth creation is covered with a mocked provider response, not a real live user.
- Actual team template lifecycle buttons, popup confirmation, successful-create popup
  closing during a stalled refresh, error retention, device Remove API/refresh passed.
- Server managed-Agent/authorization/password tests and static module graph passed.

Limits:
This revokes JioFlow application access; it does not claim to invalidate the token for every
unrelated Supabase Auth endpoint. On an open old tab, the existing heartbeat signs the UI
out on its next check; protected JioFlow operations reject the revoked session immediately.
Production creation still depends on deployed /api/manage, correct environment/permissions,
and an unused email/Jio ID. No Supabase compute/disk settings or global Auth policy changed.

Agent login email:
- An authorized Owner/Creator or Admin with user-management permission can directly change
  an Agent's email-format login ID. It need not be a real inbox; it must be unique and valid
  email syntax. Owner email verification and other non-Agent email flows are unchanged.
- A short database authorization lease is checked before the server-only Auth admin update;
  service-only finalization rechecks the manager, Agent role, current provider email and lease.
  The Agent profile keeps managed_agent=true, pending_email is cleared, and old app sessions
  are revoked. Agent logs in with the new ID and requests approval. Agents cannot self-approve
  or use this endpoint to change an Owner/Creator's email.
- Existing pending Agent login ID can be saved through Edit account to apply it immediately.
- Provider update and app cleanup are separate operations. On a cleanup error the API reports
  that the login ID changed and asks you to refresh/check before retrying.
- Local checks covered duplicate/invalid/Owner-target rejection, privileged endpoint ordering,
  service-only finalization, replay denial, cleared app pending field and managed flag.
  Hosted Auth requests were mocked; real production email-change delivery was not performed.
