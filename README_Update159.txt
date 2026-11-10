Update159 — Black dark mode, clear selected tabs, cleaner Agent Report

Apply after Update158. Replace workspace-design.css, custom-statuses.mjs and agent-reports.mjs. Deploy and hard refresh. No SQL.

Dark mode: black page/sidebar/header, near-black cards, restrained accent icons, readable labels and inputs. Revenue remains black. Profit remains a regular card. Light mode card theme unchanged.
Selected status tabs: stronger own-color fill, border/ring and bold label; tabs without custom color use brand accent. No size-changing transform. Existing status count and filtering logic unchanged.
Agent Report: Recent recorded activity section removed from rendered report. Saved activity/history is not deleted. Matching records and Confirm tab from157 retained.

Validated syntax, status color variable behavior in light/dark, report section removal and retained Confirm/list, 49-file static module build. No live deployment or browser visual QA performed.
