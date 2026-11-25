JioFlow Update156 — Shared dashboard metric order

Apply Update155 first. Replace workspace-tools.mjs and workspace-design.css, deploy, then hard refresh. No SQL needed.

Existing permitted cards appear in this order: Confirmed Customers, Completed, Orders Created, Revenue, Profit, Purchase Rate, Assigned, Unassigned, Pending Follow-up, followed by remaining cards (including Booked). No extra permissions or financial cards are granted. Revenue is black with white text across palettes.

Shared ordering intentionally overrides old saved metric ordering; hidden state and row geometry remain. Existing metric counts and click handlers are retained.

Validation: four-role DOM order, repeated application, revenue class, syntax and 49-file static build checks passed. Not deployed or visually verified on the live site.
