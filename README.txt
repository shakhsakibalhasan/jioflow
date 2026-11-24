JioFlow Unassignment + Staff Activity Fix

Database changes were already applied to Supabase project krsfldvxneoujmpquugr; do NOT rerun the migration just to deploy the frontend.

Frontend files to merge or replace in repository ROOT:
- online-client.mjs: adds jf_unassigned_activity RPC to allowlist
- record-panel.mjs: logs open action and shows Last update (staff name, action, Dhaka date/time); refreshes after status save
- assignment-picker.mjs: corrects unassignment confirmation wording

GitHub branch: make a test branch and merge changes rather than overwrite more recent edits.
Test: visit Unassigned -> a tag -> View customer as Owner/Admin. Last update should display name, Viewed, Dhaka time. Edit status or customer info and re-open: action should be Edited.
Status reset: assign customer, then Unassign using a chosen tag. Workflow status should become Processing and tag remain selected.
Note: views before the frontend is deployed are not logged retroactively. This is only for Unassigned records and authorized Creator/Owner/Admin.
No production frontend deploy has been performed by this package.
