Update 79 — Agent dashboard hydration timeout

Apply after Update 78. Replace original-sections.mjs in the application root, commit and redeploy. No SQL is required. Reload the Agent dashboard after deployment.

The dashboard initially renders live KPI widgets, then separately loads recent records to hydrate charts. That second step still used direct customer/order table reads. For Agents those reads repeatedly evaluated RLS while scanning records not assigned to the caller. A timeout in any hydration request also replaced the already rendered dashboard with an error screen.

Dashboard hydration now reads customers and orders through the existing fast, scope-checked page RPC introduced in Update 78. The previous RLS rules still apply to dependent reads. Failed hydration leaves the dashboard/KPI widgets available, shows a retry notice and marks missing chart counts as unavailable rather than reporting zero. Non-dashboard screen errors retain their existing handling.

Validation: induced timeout keeps dashboard and received KPI values; successful hydration uses two fast scoped RPCs with no direct customer/order table reads; unavailable chart values marked explicitly; supervisor Agent workspace integration and build passed. Live application changes and production latency measurements have not been performed.
