JioFlow Update186 — Customer cart column fix and rounded Save Order bar
Requires Update185. No SQL.
Replace only workspace-design.css with the file in this ZIP.

Fixes an older, higher-priority three-column order-workbench rule overriding the two visible customer cart panels. The customer cart now has its own responsive grid: two panels when space allows, one when narrow. No empty third column. Product name/SKU/price flow normally within each card. Quantity/price controls can wrap without forcing overflow.
Restores the rounded bottom Save Order bar: wide rounded Save Order button on the left, price on the right. Keeps the current clean total typography and original customer-view placement.

Cart save, customer profile editing and static module build checks passed locally. Browser screenshot verification was unavailable in this execution environment; this patch has not been deployed to production. No database/query/performance changes in this patch.
