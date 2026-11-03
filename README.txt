Update 91: Import rejection visibility
Requires Update 89. Replace live-customer-import.mjs then deploy. No SQL.
Reopen Order Import and click View last rejected import reasons. Send the first displayed reason (no full customer file needed).
All-rejected jobs now show No records were imported instead of a success message. First 200 errors are shown safely; existing rejected job errors can be retrieved without uploading again.
This does not retry rejected rows or fix an unknown database validation failure. The saved rejection reason is needed to identify that failure. No live records were changed.
Local tests cover rejected job recovery, error escaping and all-rejected completion; direct import regression and build passed.
