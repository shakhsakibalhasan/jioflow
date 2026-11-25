JioFlow Update187 — Inline Order Source and Confirm Button Guard
Requires Update186. No SQL.
Replace the 3 runtime files from this ZIP in your existing deployed app.

Fixes:
- Customer profile source was sent directly to the order API, bypassing the existing allowed-source normalizer. Inline order saving now uses the same normalization as the old New Order flow, including case handling and phone fallback for custom/import sources. No source validation is removed from the database.
- Save Order starts disabled. Selecting Confirm in the editable Status panel enables it; switching to any other status or cancelling status editing disables it again.
- The required Call Status and connected Customer Status are still checked when saving. A successful order locks the save button against duplicate clicks.
- Later asynchronous courier-settings completion and failed-save cleanup now retain the Confirm button guard.
- Missing amount defaults now populate as 0 and payment method as COD instead of blank.

The existing cart layout and rounded save bar from Update186 are preserved.
Locally checked: Owner/Admin/Agent source payload, initial/default fields, async button state, status transitions in the actual customer profile binding, order cart totals/save, repeat-click guard, existing status workflow and module build. Not deployed to production.
