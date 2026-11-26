JioFlow Processing Empty State - 2026-11-24

Changes:
- Agent Processing list only: show a centered empty-state card matching TracklyBD hierarchy with JioFlow lime theme.
- A separate server-side Processing queue count is checked before displaying the card; filtered empty tabs do not trigger the pull button.
- When queue has data, keep the normal table/list rather than the empty-state.
- The existing permitted Imported Status / Customer Tag 1 modal is retained.
- Existing Account Pull controls, saved tag palette, and other work in current combined source remain unchanged.

Deploy: Merge these two files into the latest JioFlow main source; do not upload the ZIP itself as one repository file. Commit, confirm Production deployment, verify with an approved Agent that has zero pending Processing records.

The backend must already have jf_agent_pull_config / jf_agent_pull_take and each Agent must be enabled by Admin.
