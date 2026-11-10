JioFlow Update 141 — Approval details, Profile, Settings, layout editor

Install:
1. Run Database141.sql in Supabase SQL Editor.
2. Replace the 9 application files from this ZIP at the repository root.
3. Wait for deployment Ready, then hard refresh.
Includes the Update 140 approval/login styling. Existing Update 139 follow-up
completion SQL remains independent and should already be applied.

Approval details:
- The full login notification card is clickable and keyboard accessible.
- Compact popup shows Agent name, email, phone, Jio ID, business, role,
  browser/system, device type, request time in Bangladesh and request status.
- Previous approved session is shown when available. Approve/Decline is enabled
  only after the request details load and only while the request is pending.
- Existing authorization and single-session approval remain server enforced.
- Only device user-agent/type are newly stored for the current authenticated
  Agent session; device IDs and authentication tokens are never exposed.
- Old requests may lack device details. Open/reload the Agent session after
  installing this update to collect browser/device details for that session.

Profile and Workspace Settings:
- Centered narrower profile with wider side space, avatar/identity header,
  Edit profile action, two-column information and compact security section.
- Password changes remain in a popup with show/hide and invalid-field feedback.
- Agent password-reset administrator-approval requirement is preserved.
- Workspace settings use matching cards, typography, borders, spacing and buttons.

Layout editing:
- Removes stale CSS order that made moved boxes appear to snap back.
- Updates saved-height CSS variable during resize, allowing already saved boxes
  to shrink/grow; restores previous resize classes on Cancel.
- Preserves saved row identity instead of recalculating hidden rows from geometry.
- Avoids nested editable widget conflicts and changing live text as fallback IDs.
- Hide/show inspector and existing save/reload flows retained.
- Account approval background updates do not rebuild an actively edited layout.

Local verification:
- SQL twice-safe, device ownership, restricted reviewer access and no token
  projection tested using PGlite.
- Real SQL layout save/load retains title, visibility, order, font, row and size.
- Fresh DOM layout reapply, hide/show/cancel, saved-height resize, clickable
  notification, details/confirmation, profile and login interaction tests pass.
- Build and 49-module dependency verification pass.
No live SQL/deployment/browser visual validation was performed by the assistant.
