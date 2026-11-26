JioFlow Update166 — saved status summary, finance, order dates and scoped Agent list
Apply after Update165 (Database162 must already be installed).

1. Run Database166.sql in Supabase SQL Editor. It is transactional and can be run again. Do not remove authorization checks.
2. Replace the five application files from this ZIP in your repository root:
   followup-status.mjs, record-panel.mjs, workspace-tools.mjs,
   online-orders.mjs, workspace-design.css.
3. Deploy the website and hard refresh once to load the new modules.

Behavior
- Customers without a saved follow-up update open directly in the status form. After a status is saved, reopening shows the saved read-only summary with Edit status. Save returns to summary; Cancel discards the draft. A follow-up event or recorded last contact identifies an existing saved update.
- Confirm still requires saving an order. Update status remains disabled for Confirm; manually select Call Status and the connected Customer Status before creating an order.
- Product editor is shown only while editing Confirm. Existing customer-information Edit behavior stays separate.
- Profit card always shows a numeric value. No recorded costs means zero estimated profit. With partial product costs, only known-cost products contribute, with order discounts/shared charges allocated by their sales share. An explicitly recorded zero cost counts as known; an order-level product cost overrides item costs. Existing finance permission check retained.
- Each native order history card shows its own Created and, when available, Confirmed timestamp in Bangladesh time. Imported cards retain the original imported order date. Standalone order details include the timestamps too. Missing dates remain blank rather than fabricated.
- Supervisor Agent customer queries scope latest order metadata to the selected Agent before enrichment. This removes unnecessary whole-shop enrichment for these lists. Existing access checks and filters stay intact. This does not guarantee that every production timeout is eliminated; production database load/network and other queries can still need diagnosis.

Validation
- Migration applied twice in local PostgreSQL-compatible test database.
- Twelve before/after scope and status result comparisons passed.
- Finance no-cost, partial-cost, explicit-zero, full-cost and order-cost override checks passed.
- Read-only/Edit/Save/Cancel and Confirm protection checked for Creator, Owner, Admin and Agent.
- Order form regression, syntax and 49-file static module build passed.
- No live SQL execution, production deployment or browser visual verification performed.
