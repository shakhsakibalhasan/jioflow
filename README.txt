JioFlow Update120 - requires Update118 files and Update119 if applied.
Replace included account-actions.mjs, online.js and workspace-design.css. Deploy and hard refresh. No SQL.

Edit Agent profile > Permissions now has Sidebar access and Action permissions groups. Dashboard/Follow-ups/New Order are checked disabled defaults. Optional sidebar entries are named checkboxes, linked to existing permissions. Save existing confirmation as usual. No duplicate permission names; existing grants preserved. Existing module permissions (e.g. Products, Import, Users) govern both module visibility and their existing delegated capability.
Owner/Admin inspecting an Agent workspace now uses that Agent membership permissions in the sidebar rather than the supervisor own permissions. Other roles keep their own sidebar.

Local permission control/grant-payload regression, grouped checkbox/default tests, navigation/tab tests, syntax and build passed. Not deployed or browser visually verified.
