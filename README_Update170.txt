JioFlow Update 170 — Assign, Reassign and Unassign

Requires Update 169 and earlier updates.
Replace TWO existing app files: record-panel.mjs and workspace-design.css. Deploy, then refresh once. No SQL required.

Currently unassigned customer: Assign.
Currently assigned customer: Reassign and a separate Unassign action.
Reassign uses the existing Agent selection popup. Unassign opens the existing confirmation/reason popup and uses the existing guarded database action. Nothing is unassigned merely by clicking the row action.
Customer details and editable native order row/dialog labels also distinguish Assign from Reassign. Existing native order assignment editor can choose Unassigned.
Customer assignment row buttons are only rendered for permitted Creator/Owner/Admin roles. Agent cannot see them. Existing backend permission checks are unchanged.
Actions wrap inside the column instead of pushing beyond the row.

Local checks passed: both assignment states, four-role visibility, action labels, status edit/save regression, group/sidebar regression and build graph. Not deployed or visually checked in your production browser.
Trackly-style two-row Follow-up tabs are not included in this small patch.
