JioFlow Update112 — latest-order-only follow-ups and chronological purchase history

Requires prior updates through111.
1. Run Database112.sql in Supabase SQL Editor.
2. Replace record-panel.mjs in the repository root, deploy and hard refresh.

One phone remains one customer profile. The backend chooses its latest permitted dated order before applying order date, amount, source, imported status, SKU and custom tag filters. An older matching purchase cannot qualify the profile. List date and amount refer to that latest order; latest status uses the same ordering. Searching a number still shows a single profile and its latest order values. Missing dates are not invented; dated orders take precedence over undated orders. Equal dates use the existing timestamp/ID tie-break.

The Eye/View purchase cards now run oldest to newest: year, January–December, then day. All prior orders remain visible under existing permissions; the latest status calculation itself remains newest-based. Existing date-ascending list sorting, pagination, import merge and notes remain.

Validation: older9September order excluded when latest26September is outside the filter; latest26September date/amount/status returned together; old amount cannot qualify; inclusive date filtering; full/fast/selection agreement for Owner/Admin/Agent; cross-shop helper denial; repeated SQL application; chronological card rendering and escaping, notes, tab-position and action controls; build passed. No production changes performed.
