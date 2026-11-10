Update165 — avoid blank workspace flashes
Apply after164. Replace online.js, original-sections.mjs and workspace-design.css. Deploy and hard refresh. No SQL.

On same actor/shop/supervisor scope, the current original workspace stays as an inert visual preview while the replacement layout/data is being prepared. A small Updating workspace label explains the transition. Preview cannot be clicked and duplicate IDs are stripped. It is removed when real content/layout is ready or an error is rendered. Rapid transitions clean up the previous observer and preserve the prior visible preview. Different user/shop/supervisor scopes never reuse preview content.

Removed repeated full-page fade/translate animation. Initial layout setup no longer hides a whole page without a retained preview. Existing security/session/approval redirects remain immediate. Existing stale-request generations, background idle guards, search and sync mechanisms retained. Does not claim zero network latency.

Checks: DOM tests for retained preview, layout gating, disabled interaction markup, no duplicate IDs, loading/error release; sync152 and search151 regressions; syntax and49-file module build passed. No live deployment or browser visual check performed.
