Update 93 - Order Date only
Run Database93.sql in Supabase, replace the three .mjs files in their original locations and deploy.
Created At is no longer mapped to Order Date. If Order Date is missing it stays blank. Existing history dates are repaired from retained original_columns where available; no year is guessed and no upload date substituted. Created At system metadata is retained, not deleted.
Shared UI and SQL changes apply to Owner/Admin/Agent with existing permissions unchanged.
This patch does not change which order is selected as latest when a phone has multiple orders.
Tests: both spreadsheet header orders, Created At-only input, isolated SQL fixture applied twice with 2023 Order Date/2026 Created At, syntax and build passed locally. No live deployment performed.
