-- Run in Supabase SQL Editor after Database147.sql.
-- Repeat Run until "remaining" is 0. No CSV reupload is required.
-- If a batch times out, change 500 to 100; queued rows remain safe to retry.
select jioflow_private.repair_import_dates147(500);
