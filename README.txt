JioFlow + Steadfast integration bundle — code package (NOT turnkey CRM integration)

CONTENTS
api/steadfast.mjs             authenticated status, guarded booking, stored webhook history
api/steadfast-webhook.mjs     token protected event receiver, event-only storage
supabase/steadfast.sql        new dedicated tables (does NOT touch existing CRM orders)
examples/frontend-call.js     authenticated frontend API example

INSTALL
1. Back up current Github api/steadfast.mjs; upload the TWO .mjs files inside /api/.
   GitHub browser upload does not unpack ZIP. Extract locally first. Commit.
2. In the correct EXISTING Supabase database, carefully review/run
   supabase/steadfast.sql. Requires schema public.jf_profiles with columns
   id, active, deleted_at, role and roles owner/admin/creator; inspect your real
   project and CHANGE the auth logic before enabling if different.
3. Vercel Production variables (DO NOT paste their values in chat):
   STEADFAST_API_KEY, STEADFAST_SECRET_KEY
   SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY or SUPABASE_ANON_KEY,
   SUPABASE_SERVICE_ROLE_KEY
   STEADFAST_WEBHOOK_TOKEN (random high entropy 32+ character value)
   STEADFAST_ENABLE_BOOKING=false   (default/off; set true ONLY after review)
   Redeploy after variable changes.
4. Existing status example: POST /api/steadfast
   Authorization: Bearer <signed-in Supabase access token>
   Content-Type: application/json
   {"action":"status","by":"invoice","value":"INV-123"}
5. Booking example (LIVE COURIER OPERATION, requires enable flag):
   {"action":"book","invoice":"INV-123","recipient_name":"Customer",
   "recipient_phone":"01712345678","recipient_address":"Full address","cod_amount":500}
   It creates real consignments. Never submit test/fake bookings.
   Invoice reservation prevents automatic duplicates. In uncertain cases reconcile
   against Steadfast dashboard manually; do not retry same invoice automatically.
6. Saved webhook HISTORY example: {"action":"history","invoice":"INV-123"}
   THIS IS STORED WEBHOOK EVENTS, NOT STEADFAST CUSTOMER HISTORY ENDPOINT.
7. Potential webhook URL, ONLY if Steadfast supports POST JSON matching body:
   https://YOUR-DOMAIN/api/steadfast-webhook?token=LONG_RANDOM_WEBHOOK_TOKEN
   Prefer provider-supported signed header authentication where available.
   Verify actual webhook format and authentication in merchant documentation
   BEFORE configuring; if Steadfast requires different payload, adapt code first.
   Query tokens can appear in access logs; treat as secrets. Rotate if leaked.

NOT INCLUDED / LIMITATIONS
- Existing JioFlow Order Management UI wiring (requires actual components and database schema).
- Automatic changes to your existing order status (requires confirmed CRM table,
  mapping from Steadfast delivery_status, and idempotency design).
- Steadfast's separate customer history endpoint (no verified specification).
- Real-world connectivity verification (user requested verification at end).
- Courier cancellation/rebooking, tracking timeline, bulk booking, credentials rotation.

SAFETY
Review and test the existing account permissions and database migrations in staging
before enabling live booking or webhook. Credentials are only used in backend.
