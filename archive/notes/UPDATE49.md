# JioFlow Update 49
Apply over Update48 by replacing these files in the repository root and deploying Vercel. No database migration or environment-variable change is included.

- Metric card hierarchy: label upper left, brand icon shape upper right, number lower left, percentage and Previous lower right.
- Subtle upward hover movement, disabled when reduced motion is requested.
- Verified order-period comparisons use light green for a numerical increase and light red for a decrease, with directional arrows. Change is (current - previous) / abs(previous), not current share of all records. Equal values are neutral. A zero previous baseline uses New instead of an invented percentage.
- Current customer-state metrics have no historical snapshot here and retain unavailable comparison. No historical customer counts or period profit comparison are fabricated.
- Dashboard summary failures show a visible error and Retry totals. Missing fields stop saying Updating. Summary requests have a 12-second UI deadline; this is not a database query optimization, and the underlying request may still complete later.
- Existing profit/confirmation colors and Update48 features retained.

Validation: build; metric calculation tests; summary failure/timeout/retry tests; fast-workspace, record-cache, workspace-tools, and main workspace integration tests passed. Synthetic browser card layout inspected. No authenticated production totals query, deployment, or database operation performed. The production totals request's underlying failure is not established by the screenshot alone.
