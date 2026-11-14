JioFlow Update184 — Customer View Position and Amount Styling
Requires Update183. No SQL.
Replace only the 3 runtime files from this ZIP in the existing app.

- Order cart is back inside the customer main column at its original Order Products position, below customer information.
- Customer profile banner and details remain in their original positions.
- Order Summary and Choose Products retain their individual panels and product cards.
- Bottom Save Order stays on the left, total price on the right.
- Removes the pale accent total shape; uses neutral surface, fine dividers, clear amount typography and a small Total Amount label.
- No Delivery Details panel or navigation to New Order.
- Isolated order controls preserve the profile edit form and prevent accidental profile submission.
- Same guarded order RPC, Confirm requirements and duplicate-click protection.

Locally checked: cart/profile integration and placement, independent profile edit, Owner/Admin/Agent totals and save payloads, no navigation/booking, Confirm guards, repeated-save protection, static module build.
Not deployed to production. The separate Follow-ups statement timeout is not changed by this UI patch.
