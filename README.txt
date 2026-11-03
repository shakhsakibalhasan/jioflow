Apply after Update 88.
1. Run Database89.sql in Supabase SQL Editor before deploying the new client. It preserves the public import permission guards and revokes direct access to its private per-row helper.
2. Replace the included .mjs files in the project root (including build.mjs), deploy, then hard refresh.

Changes: order upload chunks up to 2,000 rows or roughly 1 MB UTF-8 payload, instead of 200. Customer-only batches up to 500 instead of 100. Order processing up to 500 rows per request instead of 100; a 4-second soft time budget commits finished rows before starting another request. Existing row validation, phone/order deduplication, row rejection accounting, saved processing jobs and progress remain. History preparation caches column lookups and avoids redundant customer preprocessing.

100,000-row batching was tested locally. It used 50 stage chunks for small fixture rows; wider rows use more chunks because of the payload limit. A 2,000-order database import completed locally with no rejected rows or duplicate stage inserts. This is not a production throughput guarantee or a 100,000-row end-to-end load test.

For very large files prefer UTF-8 CSV over PDF. Keep the import tab open. Processing jobs can resume after reload; this update does not add an independent background worker or streaming file parser. Very large files still consume browser memory. API/database/network limits can affect performance. Progress reaches 100 only after processing is complete. No live deployment performed.
