JioFlow Update 103 — latest order status, all purchase cards, inline notes

Requires updates 100–102, including Database102.sql.
1. Run Database103.sql in Supabase SQL Editor.
2. Replace record-panel.mjs in the repository root, deploy and refresh.

Shared Owner/Admin/Agent behavior:
- Follow-up list shows Latest order status, using the newest actual Order Date across imported and live purchases, independent of the selected date range. Existing follow-up status/call-status filtering remains the workflow filter, not the courier/imported status filter.
- One phone remains one customer profile. Older order uploads do not displace a newer dated purchase. Same-day ties use the recorded timestamp and ID. An order with no date cannot displace a dated order.
- View includes an All orders & products section at the bottom. Imported and live purchases appear newest first with product descriptions/items, date, status, order ID and total. Historical orders no longer stop at 25; reads paginate through all records allowed by existing permissions. Missing product details/amounts are shown as missing, not invented.
- View banner includes the latest order status alongside the independent follow-up workflow status.
- Add note opens a text box. Update note saves a customer note and immediately adds it to the notes list; errors preserve the typed text. Saving a note does not change order status, workflow status, callback or activity metrics.
- Notes use the existing follow-up editing permissions and customer/shop/session checks. Agents remain restricted to assigned customers and their permitted live orders.

Validation: DB latest status independent of matching-date filters, Owner/Admin/Agent list consistency, owner and agent note saves, empty note rejection, other-shop and unassigned customer denial, repeat SQL application; UI pagination through 1,027 history records, combined purchase cards, escaped products/notes, note controls and save/error behavior for all three roles; shared page integration and production build.
This package is tested locally and has not been deployed to the live website.
