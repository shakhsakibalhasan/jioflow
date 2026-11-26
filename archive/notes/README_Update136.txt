JioFlow Update136 — Centered Live Import Popup + Agent Phone Lookup

Update135-এর উপর এই আপডেটটি দিন।

ইনস্টল:
1. Supabase SQL Editor-এ Database136.sql পুরোটা Run করুন।
2. ZIP-এর live-customer-import.mjs, record-panel.mjs, online-client.mjs ও workspace-design.css GitHub repository root-এ একই নামের ফাইল replace করুন।
3. Vercel deployment Ready হলে Ctrl+Shift+R দিন।

Import:
• Import চাপলেই মাঝখানে modal popup খুলবে; পেজের নিচে report নয়।
• সঙ্গে সঙ্গে CSV-এর row details দেখাবে। ছোট chunk upload হওয়ার পরই সেই chunk process করে actual Created / Updated / Skipped / Failed ফলাফল দেখাবে; পুরো ফাইল upload শেষ হওয়ার অপেক্ষা করবে না।
• উপরে Running/Complete/Cancelled, processed/total, progress bar ও status counts থাকবে। মাঝের table-তে row, Order ID, customer name, phone, address, status ও কারণ দেখাবে।
• Summary ও footer স্থির; মাঝের table scroll হবে। Follow latest rows চালু থাকলে সর্বশেষ processed rows দেখাবে। উপরের status tabs এবং pagination দিয়ে আগের ফলাফলও দেখা যাবে।
• Cancel Import চাপলে চলমান batch শেষ করে পরের batch বন্ধ হবে। ইতিমধ্যে সেভ হওয়া রেকর্ড থাকবে। কোনো existing order delete বা courier booking cancel করা হয় না।
• Cancel/Complete হলে Close দিয়ে popup বন্ধ করা যাবে। চলার সময় Escape দিয়ে popup হারিয়ে যাবে না।
• History job cancellation server-এও সংরক্ষিত হয়; cancelled job-এ নতুন streaming chunks দেওয়া যাবে না।
• Customer-only CSV-তেও একই popup ও cancel ব্যবস্থা।

Agent phone search:
• একই business-এর সম্পূর্ণ valid phone number search করলে নিজের কাছে assigned না হলেও customer-এর order details দেখাবে।
• অন্য customer-এর search result read-only; assignment বা edit/write permissions বদলায় না। নিজের assigned customer-এর আগের কাজের flow বহাল।
• সাধারণ Assigned Customers তালিকা আগের মতো নিজের assigned customer দেখাবে। অন্য business-এর তথ্য পাওয়া যাবে না; partial number দিয়ে এই বিস্তৃত lookup হবে না।
• Customer lookup-এ product cost/profit/private operational fields প্রকাশ করা হয় না।

যাচাই:
• Real local PostgreSQL engine-এ migration দুইবার apply, streaming partial progress, cancellation, retained records, nonassigned Agent lookup, invalid phone ও cross-business denial পরীক্ষা করা হয়েছে।
• UI/DOM-এ upload চলাকালে popup ও row results, current batch-এর মধ্যে Cancel, পরের batch বন্ধ, Close, customer-only cancellation পরীক্ষা করা হয়েছে।
• আগের layout/date/report/cache checks এবং build-এর 49-module dependency graph পাস।

এই package স্থানীয়ভাবে পরীক্ষা করা হয়েছে। আপনার live Supabase বা Vercel-এ এখান থেকে apply/deploy করা হয়নি; browser pixel screenshot comparison করা হয়নি।
