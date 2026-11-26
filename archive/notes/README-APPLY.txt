JioFlow — Order Import page UI & session-only summary fix

Updated files (replace ONLY these in your existing repository):
1) live-customer-import.mjs
2) workspace-design.css

Changes:
- Last Import Summary appears ONLY once the current-page upload is completed.
- Going to another section and returning does NOT restore an earlier completed summary.
- Starting another upload hides the preceding summary until the new upload finishes.
- Pending/resumable saved imports and rejected-import reason lookups remain available.
- Import / Clear / Resume buttons are spaced consistently; rejected-import button has its own clean row.
- Subtle import card, dropzone, responsive button, and summary styling improvements.

Installation:
1. Extract the changed-files ZIP.
2. In a NEW feature branch of the CURRENT JioFlow GitHub repository, replace the matching two files at the repository root.
3. Create a Vercel Preview build and test with a SMALL CSV. Check import results and navigate to another page then back.
4. Verify Owner, Agent approvals and all other existing screens still work before merging/deploying.

IMPORTANT: Source based on the JioFlow source ZIP supplied in the conversation, plus the previously prepared scheduling fixes. Do not blindly overwrite newer GitHub changes; compare and merge the two files if they changed afterward.
No production database, user, import job, or project settings have been modified by this ZIP.
Tests performed locally: node --check, npm test, npm run build. Actual Vercel/Supabase end-to-end test not performed.
