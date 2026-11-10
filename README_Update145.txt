JioFlow Update145 — Fast import batches and Order ID duplicate rules
Apply after the existing Update144 application. SQL requires the Update138 importer.

INSTALL
1. Run Database145.sql (safe to run twice).
2. Replace live-customer-import.mjs and online-client.mjs in the project root.
3. Redeploy, then Ctrl+Shift+R before starting a new import.

RULES
Existing Order ID: Skipped. The row does not modify the existing order or customer, even if its incoming details/phone differ. This prevents a duplicate from mutating another customer.
New Order ID + existing phone: update the same customer and add its new order history; result Updated.
New Order ID + new phone: Created.
Customer-only files: matching phone is Updated, never skipped merely for phone duplication. Repeated phone rows are merged into the same customer.
Invalid rows remain Failed. Shop isolation and import permissions remain enforced.

PERFORMANCE
Up to 500 rows are committed per request instead of one, bounded by the existing 1 MB payload limit. A normal 40,000-row file requires about 80 save requests rather than 40,000, plus job setup. Each request returns its actual row results without another result-fetch call. Incremental table rendering runs once per batch; result deduplication uses a Set.
The popup retains Created / Updated / Skipped / Failed, per-row details, auto-scroll and Done. Cancel waits for the active batch, then prevents the next batch; already saved data stays saved.

10-SECOND TARGET
40,000 fully saved rows in 10 seconds is NOT verified or guaranteed. Local PGlite testing of 500 new rows took around 1.7 seconds; an existing-ID skip batch took around 0.26 seconds. These are local samples, not production measurements or a 40,000-row benchmark. Actual speed depends on database work, payload size, network and server capacity. This patch removes the main per-row network bottleneck but is not a set-based bulk importer.

VALIDATION
Real SQL twice-safe migration; 500 actual inserts, 500 existing-ID skips; retry idempotency; changed data with same ID still skipped; new ID with same phone updates one customer and adds history; customer-only repeat updated; invalid row failure; foreign-shop denial. DOM test: 600 rows in two save requests, all four counters, live batch results, Cancel stops before next batch, Done resets file picker. 49-file deployment module graph passed. No live SQL/deployment performed by the assistant.
