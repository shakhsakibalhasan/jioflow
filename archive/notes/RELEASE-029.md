# JioFlow 029 — notification inbox

Mark all as read applies to the active business scope, including all unread records beyond the recent-50 preview. Per-notification Delete dismisses only the current account’s copy; other recipients and pending approval requests are unchanged. Deleted items stay hidden across reloads. Inbox refresh updates only the bell/popup, retaining the current page and open popup. Refined header, compact activity rows, readable timestamps, empty state, and theme-aware styling.

Apply JioFlow-Database-029.sql (migration 022) after migration 021 / Database 025. No other new SQL is required for users already through 021. Upload the complete source ZIP and redeploy Vercel.
