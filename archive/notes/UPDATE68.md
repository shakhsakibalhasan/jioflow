# Update 68 — Transparent courier logos and badge containment

Apply after Update 67. Replace the included files at their existing relative paths and commit for Vercel deployment. No SQL, credentials or environment changes.

- Four transparent PNG assets from the supplied original logos. Preserve the original wordmarks and their proportions. CarryBee includes its original tagline. REDX has black RED and a red X, as requested.
- Use normal image containment instead of cropping the logo through an SVG view box.
- Consistent 136 × 34 px white badge with internal padding and object-fit: contain. Header height 48 px. Long uploaded logos also stay within the badge.
- Remove the duplicate background logo watermark to keep the visible logo entirely inside its badge. Brand header colors remain unchanged.
- Setup choices, courier list and booking headings use the same PNG assets.

Verified transparent alpha in all four PNG files. Desktop and 390px phone browser checks: all four assets load, all logo bounds stay inside the white badges, phone has no horizontal page overflow. Courier/UI regression tests and build passed. The preview image contains labelled sample values, not live courier results.

Courier capability and active/verified booking rules remain as in Update 67. This is a visual correction, not a new courier adapter or production deployment.
