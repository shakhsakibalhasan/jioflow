JioFlow Update146 — Bounded adaptive import + last import summary
Apply AFTER Update145 SQL and application files.

INSTALL
1. Run Database146.sql in Supabase SQL Editor. Transactional; safe to run twice.
2. Replace these TWO application files in your project root:
   live-customer-import.mjs
   workspace-design.css
3. Redeploy and Ctrl+Shift+R. Select the CSV again after reloading if the previous import was paused. Previously committed records are retained and repeated Order IDs skip safely.

IMPORT
Starts at 50 rows, grows up to 250 when requests finish quickly, shrinks when slow, and halves/retries at the same offset for timeout/temporary network errors. Bounded retries stop if even one record keeps failing; permission errors are not retried.
Server processes only a bounded number of rows and checks an approximately 0.8-second work budget between rows. It no longer assumes every staged row finishes in one transaction. The uploader advances only through confirmed contiguous results; partial batches continue without losing unprocessed rows.
Existing Order IDs in each incoming chunk are skipped in one database update before per-row customer work. New ID + existing phone updates the customer and adds history; both new means Created. Existing ID means Skipped without changing that customer/order. Existing permission and business isolation checks remain.
No global timeout increases, service-role credentials or disabled constraints are used. A single slow/blocked database statement can still time out; adaptive retries handle common overload, but cannot guarantee zero timeouts or Trackly's speed on different infrastructure.

INTERFACE
Same compact running popup, dot counters, per-row results, auto-scroll and Cancel. Upward manual scroll pauses auto-follow. Done clears the selected file. Below the upload card, Last import summary displays five equal tiles: Total rows / Created / Updated / Skipped / Failed. Uses JioFlow theme with semantic value colors. Summary stays after Done and reloads the latest completed history job on reopening the page. No third-party customer data or credentials are stored in the browser.

VALIDATION
Real local SQL: twice-safe patch, bounded partial-progress drain, set-based duplicate skips with accurate counters. Cumulative tests retain business isolation, Order ID skips, phone updates and import history. DOM: forced timeout -> smaller same-offset retry; partial result cursor; batch growth/shrink; no lost/duplicate result rows; Cancel; auto-scroll handler; five summary tiles retained after Done. Deployment graph 49 files passed; status-column regression passed.
Live production speed and browser visual verification were not performed. The observed Trackly sample was 3,728 rows in 11.74 seconds, not 40,000 rows in 10 seconds. This release does not claim a measured speed match.
