JioFlow Update 192 — deployed Agent controls and created-user visibility

INSTALL after Update191
Replace the supplied ROOT source/runtime files, including original-view-adapter.txt.
Keep that TXT file: it is build source, not a readme. Also replace both HTML entry files.
Deploy through your normal build process and reload the site.
No new SQL is required; Database191.sql from Update191 must already be installed for its
existing device-removal/login-email functions. No production change was performed here.

PACKAGING CORRECTION
Update191 included the generated original-views.js but omitted its edited source adapter.
The existing build-original-views.mjs recreates original-views.js from original-view-adapter.txt.
A project rebuild could therefore replace the fixed controls with old disabled handlers.
This patch supplies both the adapter source and generated view, with versioned HTML entries.

CONTROLS
Agent cards now also receive explicit live Remove and Activate/Deactivate buttons when the
current account has the existing lifecycle permission. This runs after the legacy template
has rendered, so these controls do not depend on prototype handlers.
Database authorization and existing confirmation dialogs remain. Successful removal or
activation/deactivation updates the visible card immediately, then refreshes the directory.
A slow directory refresh no longer holds a completed lifecycle popup open.

CREATE VISIBILITY
Newly created Agent is placed first on Users & groups, before pagination. Search/status filters
are reset for the created Agent. Removed memberships are excluded. The creation API must
still return a confirmed user ID before the popup closes. Failed creation stays open with error.
This corrects list visibility after a successful creation; it does not fabricate an Agent or bypass
provider errors. Existing email and Jio ID uniqueness rules remain.

TEXT
The requested Add user policy paragraph is removed. Common original/demo/account-policy
hints and account-section subtitles are cleaned from rendered screens/popups. The redundant
password-instructions-only block in Edit account is removed. Labels, necessary confirmations,
verification actions, validation and failure messages are kept. No secret credentials are added.

FILES
account-actions.mjs, online.js, workspace-pages.mjs, original-view-adapter.txt,
original-views.js, index.html, online.html, online-orders.mjs.
The included online-orders.mjs is the existing released inline-cart controller, preserving the
prior Confirm-only Save Order, source handling and delivery behavior.

TESTS
Actual template lifecycle and explicit legacy-disabled-button replacement; create-success popup
closing; failure retention; new Agent first among 12 paginated members; device controls;
module graph; server account validation. A local database test also verified that a newly
created pending Agent's profile/membership is visible to the Owner through authenticated RLS.
Patch-overlay rebuild verifies the adapter changes survive build generation.
Production API calls and final live behavior were not tested; no live user was created.
