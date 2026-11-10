JioFlow Update 143 — SQL compatibility and shared statuses
Replaces Update142; includes its status fixes. Requires the existing Update139–141 setup.

The reported error was caused by Update142 trying to find an authorization clause by its text. Older installed functions use different text. Database143 uses explicit checks instead: active approved session, assign permission or approved Agent membership, customer visibility, and active shop. It does not depend on old function formatting.

INSTALL:
1. Run Database143.sql in Supabase SQL Editor instead of Database142.sql. Safe to run twice. If Update142 failed, simply use this corrected SQL.
2. Replace ALL FOUR application files in the deployed project root:
   custom-statuses.mjs
   followup-status.mjs
   record-panel.mjs
   workspace-design.css
3. Redeploy, then Ctrl+Shift+R in every open panel.

Includes settings-driven Follow-up status tabs and dropdown options for all roles, active-label validation, exact-label filter/count keys, No Answer save, renamed Confirm reporting, and the removal of category text beside status capsules. CSS also hides old category markup in Regular and Permanent Customer settings. Configuration permissions are unchanged. History is retained.

Verified locally: old Database54 function replaced successfully; SQL twice-safe; Owner/Agent full/fast bucket/counts and Pending removal; renamed and removed statuses; renamed Confirm; foreign business mutation denied. DOM tests cover all roles and regular/permanent settings, preserving action controls. Live SQL/deployment has not been applied by the assistant.
