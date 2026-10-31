Update 80 — Customer/price preview in Delivery details

Apply after Update 79. Replace online-orders.mjs in the application root, commit and redeploy. No SQL is required.

The shared New Order form now shows customer name, phone, address and delivery area inside Delivery details, followed by subtotal, any discount/delivery charge, total, recorded advance and remaining due. Order summary contains the price breakdown only. Customer input, product quantities and monetary fields update both price previews together. Existing courier choice, shipping note, booking controls and role permissions are retained.

The shared layout applies to Agent, Admin, Owner and Creator. No new dependency or backend endpoint is required.

Validation: role-by-role UI tests with a product, discount, delivery and advance; correct total/due in both panels; customer text escaped; price-only summary; courier/note fields retained. Existing order-summary/Agent-binding tests and build passed. Prepared locally; not deployed live.
