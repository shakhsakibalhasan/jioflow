JioFlow Import Update 39 - patch for Update 38 only

Required baseline: JioFlow Update 38 must already be uploaded.
If your repository has an older or unknown version, use the complete JioFlow39.zip instead.

Replace these three files in your GitHub repository root:
- import-document.mjs
- live-customer-import.mjs
- online.js

Upload the files directly, not the ZIP. Keep their names unchanged.
Commit all three files together, then allow the connected Vercel project to deploy.
No SQL or environment-variable changes are needed.

Included changes:
- One customer/order import uploader.
- Removed detected-column controls, three-row preview and separate history box.
- Added structured Notepad/text and JSON input.
- Files with Order IDs use the existing history import service automatically.

This patch does not add OCR for scanned PDFs or understand arbitrary prose.
