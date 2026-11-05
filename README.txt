Update 94 - Only Phone Number required
Apply after Updates 89, 92 and 93. Run Database94.sql in Supabase SQL Editor, then replace the three .mjs files in their original locations and deploy.
Phone Number is the only required import column. Invalid phone numbers and invalid supplied field lengths are still rejected. Customer name, Order ID, Order Date, amount and all other columns are optional.
Missing name: keep the existing customer name; a new customer uses their phone as the display label. Blank customer fields do not erase existing details.
Phone-only files import customer profiles. Files with order/extra columns retain order history. Same normalized phone uses the same customer profile.
Missing Order ID: a stable AUTO ID is computed from normalized phone and order details. Identical reuploads merge; different dates/details produce separate history. Without a real Order ID, two identical purchases cannot be distinguished. Provide Order ID to update the same order after changing date/amount/details.
Existing staff import permissions and Agent restrictions remain enforced. No courier bookings are created.
No live deployment or production changes performed.
