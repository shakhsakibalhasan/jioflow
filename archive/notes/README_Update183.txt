JioFlow Update 183 — Customer View Order Cart
Requires Update182 and its earlier database updates. No SQL migration in this patch.

Replace the 9 runtime files in this ZIP in your existing deployed app. Do not replace the whole project. Keep every other file, configuration, asset and database record.

Changes:
- Customer View now always shows Order Summary and Choose Products, with the existing cart cards and live totals.
- Save Order and total price sit together in the bottom capsule.
- Customer name/phone/address and current assignment come from the profile, including saved edits.
- Discount, advance, delivery charge, payment method and transaction fields remain in Order Summary.
- No Delivery Details panel. No Create Order handoff to another screen.
- Save runs the existing guarded, atomic jf_save_order RPC and remains in Customer View. The saved form is locked against a second click.
- Keep the existing Confirm + call/customer response requirement. Select Confirm in Status (Edit status if needed), choose the required outcomes, then Save Order. A successful order updates the visible status to Confirm.
- New Order and Couriers navigation entries are removed; old route requests go to Follow-ups. Courier integrations and historical order data are retained.
- Inline order entry does not load courier booking settings and does not book a parcel.

Validation: inline cart for Owner/Admin/Agent, correct customer/items/amounts, status guard, duplicate-click lock, no route handoff or booking, independent profile-edit form, and build graph checked locally. This ZIP has not been deployed to production.

Important: This UI patch does not fix the separate Follow-ups SQL statement-timeout shown in your screenshot. Removing menu entries is not a database performance fix.
