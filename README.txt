Update 98 - Calendar range click fix and aligned amount controls
Requires Update 96/97. Replace followup-filters.mjs and deploy, then refresh browser. No SQL.
First date click selects one day; second date click selects inclusive range in either direction. Calendar remains open between clicks. Apply filters commits the selection.
Fixed a bubbling-click issue: calendar rerender detached the clicked button, causing the outside-click handler to close the calendar.
Amount type and Exact amount are side by side with equal input heights on desktop/mobile. Range chips remain compact.
Owner/Admin/Agent shared UI; actual bubbling clicks tested for single date/range and no premature close, exact/range switching and existing Apply regression. Build passed. No live deployment performed.
