# JioFlow 026 — original logo and icon

Includes the entire 025 source update. Database requirements are unchanged: apply 021 using JioFlow-Database-025.sql after Database 024 (through 020). No additional database migration for branding.

- Exact supplied PNG logo is used in the sidebar and login/password header. Original file bytes, colors, typography and transparency are preserved.
- CSS frames the logo's transparent outer margins without modifying the file. A small dark backing keeps the supplied white lettering readable in Light mode.
- Exact supplied icon is used for the stationary center of the rotating loading ring and for browser/Apple touch icons. It is proportionally fitted and never recolored by theme palettes.
- Original uploads remain unchanged. Browser icon caches may retain an old icon briefly after deployment.

Validation: source-file SHA-256 comparison, existing 20 regression files and production build. No production Vercel deployment or account data was changed.
