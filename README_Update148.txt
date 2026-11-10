JioFlow Update148 - Smooth import and notification sounds

Replace these 3 files in GitHub, deploy and hard refresh:
live-customer-import.mjs
notifications.mjs
workspace-design.css
No SQL required. Retain Database146/147 already supplied.

Import: persistent progress element with smooth fill transitions; frame-based easing toward newest committed rows. Scroll upward/touch to pause auto-follow, return to bottom to resume. Actual saved counts are retained; no artificial upload delay or invented progress.
Notifications: shared two-note sound for newly received inbox notifications across roles. Different three-note sound for opened dialog popups. Existing inbox on first load is silent and repeat redraws do not replay a notification.
Browser audio requires one click/key interaction on the page and an unmuted tab/device. Closed pages cannot play these in-app sounds. No browser push service is added.

Checks: adaptive import retry/partial commit/Cancel/Done regression, sound baseline/dedup/tone variants, JS syntax and 49-file release build passed locally. Not deployed live. Visual/audio review in a real browser remains required.
