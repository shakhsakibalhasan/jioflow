JioFlow Order Pull API Allowlist Hotfix

Root cause: account-actions.mjs calls jf_agent_pull_option_counts, but online-client.mjs rpcRaw150() allowlist did not include this RPC name. The browser throws "This action is not enabled." without calling Supabase.

Safer fix when main branch may have newer changes: open online-client.mjs in GitHub, find the single occurrence of:
'jf_agent_pull_config','jf_agent_pull_take'
replace exactly with:
'jf_agent_pull_config','jf_agent_pull_option_counts','jf_agent_pull_take'
Commit to a test branch and deploy a Preview first. After success, promote to Production.

If and only if the source version is the same as the full source in the earlier Premium package, online-client.mjs in this ZIP may be used to replace the file. Do not overwrite a newer online-client.mjs without merging.

No database migration is needed for this allowlist fix. It does NOT automatically enable Order Pull for any agent: an authorized admin must save the agent's permission and filters.
