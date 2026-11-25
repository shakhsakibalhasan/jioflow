JioFlow Update 43 — cumulative changed files after Update 41 (includes Update 42).
1. Supabase SQL Editor: run the COMPLETE Database43.sql. Requires existing migration 026. Includes 027–030 and can be rerun in this order.
2. Upload ALL source files from this ZIP into the same paths in your existing GitHub repository. This ZIP is a patch, not a complete replacement project.
3. Wait for successful Vercel deployment, then hard refresh (Ctrl+Shift+R).

WHAT CHANGED
- All Orders and courier lists contain live orders only. Uploaded rows remain in customer follow-up/imported history, without automatic Confirmed/Delivered counts.
- Order statuses use the order record; follow-up outcomes remain separate.
- Agent uses shared Dashboard/Order/Courier UI, retaining own-data, finance restrictions and admin-granted editing/booking permissions.
- Dashboard action KPI boxes merge into the main top summary. KPI strips use responsive grids. Full Status Breakdown is visible without its inner scrollbar.
- New Order input widths fit their panels without horizontal overflow. Product catalog keeps its intended internal vertical scrolling.
- Current status rendering no longer waits for optional settings, prior-period comparison or finance tasks. Dashboard opens its shell before record hydration; downstream reads run concurrently. Read-only scoped memory cache deduplicates quick revisits and invalidates on save/reload.
- Group-wise assignment works from selected customer checkboxes via Assign selected, using the Agent or Group selector.
- Full detail/action pages, Eye/Assign follow-up buttons, inline notes and editable unbooked products from Update 42 included.
- Unbooked order details: recipient name/phone/address/area/source/status/note/assignment editor. Products, quantity, discount and delivery charge have their own save. Existing recorded payments are retained; booked order guards remain.
- Layout: actual width/height resize, cross-group drag, Move up/down and Move to section controls, Save/Cancel and saved placement restoration.
- Authorized shop page layout saves are shared with the shop's users. Agents can view but cannot edit layouts. Each shop/page remains separate.
- Order Date columns and address hover text included.

VERIFICATION
Local SQL tests through migration 030 and 11 JS regression test files passed. Browser checks confirmed no horizontal New Order overflow, 17 Agent KPI boxes in the top summary, no separate action KPI strip and full visible Status Breakdown. Synthetic data only.

NOT DEPLOYED TO YOUR VERCEL / SUPABASE
No production SQL or live courier booking was performed. First network fetch still depends on connection/server latency. This patch does not guarantee zero latency or fix provider API blocking. Shared layouts are picked up on page reopening/refresh; this is not realtime push to every already-open device.
Source commit: a1c93dd157ff8c288df2cc2dacd16de6b5d6db65
