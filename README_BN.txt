JioFlow Activity Timeline + Notes (incremental update)

The new Supabase migration include_status_notes_in_customer_activity_timeline has ALREADY been applied. DO NOT run it again.
The patch adds full note text to the timeline: status form notes appear beneath Changed status, and standalone notes beneath Added a note. Unassign entries continue showing reset and tag.

Files to merge on the branch used for earlier Activity Timeline release: record-panel.mjs and workspace-design.css. The archive also contains the other earlier files for convenience.

The frontend changes are NOT deployed; test on Vercel Preview before Production.
Historical notes from before enabling the new event logger will not automatically be added to the activity timeline.
