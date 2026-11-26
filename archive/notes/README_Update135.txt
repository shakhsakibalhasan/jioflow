JioFlow Update 135 — Search, Import Results, Reports, Dates & Layout Editor

আগে Update134 ইনস্টল থাকতে হবে। এটি Update134-এর পরের পরিবর্তিত ফাইলের প্যাকেজ।

ইনস্টল:
1. Supabase SQL Editor-এ Database135.sql সম্পূর্ণ Run করুন।
2. ZIP-এর কোড ফাইলগুলো GitHub repository-র root-এ একই নামের ফাইল replace করুন। README ও SQL repository-তে রাখলেও build-এ সমস্যা হবে না।
3. Vercel deployment Ready হলে Ctrl+Shift+R দিন।
কোনো courier booking বা customer/order deletion এই আপডেট ইনস্টল করলে চালু হয় না।

যা বদলেছে:
• উপরের search-এ ফোন লিখলে বিস্তারিত result cards: customer, all matching imported/new purchases, SKU, status, source, tags, identifiers, address, amount এবং View Details। Account/shop/Agent data permissions বহাল। Orders-এর order-ID search আগের মতো কাজ করে।
• নতুন import-এ প্রতি CSV row-এর Created / Updated / Skipped / Failed result ও কারণ, counts, progress, status tabs এবং 200-row pagination। একই Order ID-এর অপরিবর্তিত তথ্য Skipped; পরিবর্তিত তথ্য Updated। একই phone-এর আলাদা purchase history রাখা হয়; customer profile একটাই থাকে। Customer-only CSV-তেও প্রতিটি input row-এর ফলাফল দেখায়। Invalid date একটি row-কে Failed করে; valid rows চলতে থাকে।
• পুরোনো completed import jobs-এ এই update-এর আগেই মুছে যাওয়া row details পুনর্গঠন করা হয়নি। নতুন imports-এ পূর্ণ result details থাকবে।
• Agent Reports: Total Agents, Online Now, Assigned, Confirmed, Revenue; Orders by Agent donut, Overall Purchase Rate; নাম/email/Jio ID/phone search। Sorting ও drill-down বহাল। Online Now মানে অনুমোদিত Agent-এর গত 90 সেকেন্ডে heartbeat আছে। Report screen প্রতি 30 সেকেন্ডে refresh হয়; input বা dialog-এ কাজ করলে পরের চক্রে চেষ্টা করে।
• Purchase Rate একই সংজ্ঞায়: selected-period purchasing customers / current completed assigned customers। Assignment/Completed সংখ্যা current assignment snapshot; order/revenue selected period। Counts আলাদা অর্থের হলে UI-তে তা লেখা আছে।
• Shared date popup: Today, Yesterday, Tomorrow, Last 7 Days, Last 30 Days, This Month, Last Month, This Year, Last Year, Lifetime; specific date, custom range, previous/next period; live Bangladesh clock। Calendar range endpoints brand color, ভিতরের দিন ash; mouse drag ও two-click selection।
• Selected small controls-এর tint বাড়ানো, capsule controls, text hierarchy, table hover/dividers, aligned refresh, softer popup/floating shadow। Agent Follow-ups submenu-তে down animation ও aligned chevron।
• Owner/Admin/Creator-এর Assigned, Unassigned, Due Today tabs ফিরেছে। Agent-এ এগুলো বাদ। আগে চাওয়া Cancelled navigation removal বহাল; historical records রাখা হয়।
• Layout editor: box drag/arrow movement-এর আসল DOM order save হয়; নতুন size legacy repair মুছে দেয় না; 8px resize increments ও sensible minimums; single box width resize; Hide সঙ্গে সঙ্গে কাজ করে; inspector দিয়ে hidden box ফেরানো, title ও 11–24px title text size, Auto height, Save/Cancel। Old layouts-এর unsafe compressed geometry repair বহাল।
• Layout write-এর পর cache invalidation; তাই পুরোনো position/visibility আবার ফিরে আসে না।

এই প্যাকেজে থাকা original-view-adapter.txt এবং original-views.js দুটোই replace করুন। Build existing modules ব্যবহার করে; নতুন module dependency নেই।

স্থানীয় যাচাই:
• Database migration দুইবার apply: Created/Updated/Skipped/Failed, result filters, customer-only results, Agent access denial, live/expired presence, report phone field।
• UI/DOM checks: search cards, role-specific tabs, Agent name/email/code/phone search, date presets/ranges, import row failures/duplicates, layout save/reload/hide/cancel/resize।
• Existing popup/approval, report sorting, SKU/product detail regressions।
• Build ও static import graph: 49 files, missing dependencies নেই।

এই প্যাকেজ স্থানীয়ভাবে যাচাই করা হয়েছে। আপনার live Supabase/Vercel-এ এখান থেকে apply/deploy করা হয়নি; browser pixel comparison বা real courier booking করা হয়নি।
