Update 82 — Readable filter text and uncropped dropdown values

Apply after Update 81. Replace followup-filters.mjs in the application root, commit/redeploy, then reload. No SQL is required.

Filter labels are 12px and headings 13px. Desktop input/dropdown text is 13px in 42px fields. Native controls explicitly use border-box sizing, normal line height and zero vertical padding to avoid clipping their text. Mobile controls use 16px text and 44px height. Payment options use readable 12px labels across four desktop columns or two phone columns. Date inputs align along their bottom edge. Existing compact groups, template-only custom tags, one Apply button and draft multi-filter behavior are retained.

Validation: all-role template-choice UI tests, draft multi-filter Apply regression and build passed. Visual rendering on the user's browser still needs deployment verification; not deployed live.
