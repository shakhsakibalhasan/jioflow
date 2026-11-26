JioFlow saved-colors first-paint patch

Purpose: initial color equals the last saved color, without an intermediate fallback palette or color-transition effect.
Files: index.html, workspace-design.css.

Use only with the matching JioFlow source revision. Merge rather than overwrite if GitHub main has newer changes.
The inline prepaint script mirrors the existing appearance.mjs palette and localStorage key; it does NOT write any new color, alter customer data, tags or agent permissions.
The stylesheet disables tag/status color transitions and reserves stable filter tab height.

This patch alone cannot guarantee zero layout shift from asynchronous data changes elsewhere, and the app still needs a Preview deployment and browser test.
No live deployment or database migration was performed.
