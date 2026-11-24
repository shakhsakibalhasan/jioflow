JioFlow Agent Order Pull — Visible Admin Configuration Fix

This package updates the prior Combined Order Pull release.

Updated files:
- account-actions.mjs: Always display a Take More Orders section directly under Workspace access when editing an Agent, with a Configure button if an active membership is available. If not, show a descriptive membership warning instead of hiding the control.
- workspace-design.css: Size, spacing, and visual treatment for the new section.

Installation:
1. Update these individual files at the repository root, preserving all other files. Do not upload the ZIP file itself to the repository.
2. Confirm the files are committed to the branch that Vercel builds for Production.
3. Vercel build should run node build.mjs. Compare deployment commit and domain.
4. Open Account Access > Edit Agent. Look for the Take More Orders section immediately after Workspace access.
5. If the section indicates no active Agent membership, complete membership setup first. Do not grant access manually in SQL.
6. Configure 20 per pull, 50 daily, require empty queue, allow Imported Status and Customer Tag 1 as needed, then save and test with an approved Agent session.

Database Pull Settings start disabled by design. Do not force-enable an Agent without authorization.

Node syntax check, build, unit and upgrade tests passed in the local source snapshot.
This does NOT change the live website until the files are committed and Vercel is redeployed.
