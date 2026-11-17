JioFlow Update 190 — Account popup, real Add user and background refresh

Requires the existing Update188 application/server and Update189 database changes.
Replace the four root files from this ZIP, deploy normally, then hard-refresh (Ctrl+Shift+R).
No SQL is needed for Update190. No live deployment, database change or real user creation
was performed while preparing the patch.

1. Edit account popup keeps its current size.
   Account details, Devices & sessions, Profile photo, Workspace access, Permissions and
   Password & verification now have clear section headings, consistent labels/helper text,
   restrained borders, compact spacing and a Save changes footer.
   Devices are compact cards in two columns on desktop and one on small screens.
   Browser/OS, device type, activity state, login/approval/activity dates are retained.
   Long device history scrolls within its section. Existing profile/permission save callbacks
   and device RPC authorization are unchanged.

2. Users & groups has only the Add user creation control.
   The duplicate Add Account control is removed on this page only.
   Account Access retains Add Account.
   The actual original-template Add user button is now connected to the working managed
   Agent form on Users & groups, not the disabled Original form preview. It asks for name,
   email-format login address, unique Jio ID and initial password. Only Agent role is offered
   on this page. Existing create API and role authorization still enforce creation rules.
   Every new Agent login still requires approval.
   If the API returns an error after deployment, the form displays that error; provider keys,
   duplicate email/Jio ID and server configuration still need to be valid.

3. Background-refresh skeleton flash corrected.
   The retained page preview no longer disappears as soon as the intermediate loading
   skeleton is inserted. It stays until actual new content is ready.
   Previews retain full height so a scrolled list is not clipped to one viewport.
   Empty/loading pages are not stored as valid previews.
   The preview is inert and cannot submit actions. Initial visits still show a loading state.
   This is a page-rendering correction, not proof that all production query timeouts are fixed.

Validation:
- actual original Users & groups template Add user click routes to the managed create form;
- create form submit calls invite_account with Agent, Jio ID and password;
- duplicate Add Account removed only from team page;
- sectioned popup preserves profile and permission fields, device cards and Refresh;
- intermediate skeleton retains old data and final content releases the preview;
- managed Agent server/API authorization, account validation, inline order regression,
  background sync behavior and static build graph checks passed.
- visual CSS is responsive; an actual browser screenshot could not be generated in this
  environment, so final appearance should be reviewed after deploying.
