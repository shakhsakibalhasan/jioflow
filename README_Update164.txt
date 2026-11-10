Update164 — Manual Confirm outcomes and immediate locked update button
Requires Database162 and its order flow. Apply after163. Replace followup-status.mjs and workspace-design.css, deploy and hard refresh. No new SQL.

Selecting Confirm clears prior Call Status and Customer Status. Opening an already-Confirm customer also starts with no selected outcomes. Connected requires manually selected customer response; Not Connected does not. Update status is disabled immediately, marked aria-disabled and visually neutral. Creating/booking remains gated by explicit selections. Changing away and back to Confirm clears outcomes again. Repeated sync does not erase newly chosen values. Status is saved only through the existing162 successful order transaction.

Tests: eight combinations (four roles x Processing/already Confirm), selection reset, immediate disabled attribute, manual response requirement, switching away/back, direct-handler no-write guard, static49-file build passed. Not deployed or visually checked live.
