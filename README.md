Latest update: RELEASE-031.md — Agent reports and supervisor dashboards.

Latest update: RELEASE-030.md — unified order lists, quick revisits and notification inbox.

Latest notification inbox update: RELEASE-029.md.

Current branding update: RELEASE-026.md; includes all performance and tab count changes from RELEASE-025.md.

Current update: see RELEASE-025.md for faster navigation, stable lists, status tab counts and box connections.

Latest cumulative update: RELEASE-024.md. Install the new Database 024 bundle after the previous Database 022 update.

Latest update: RELEASE-023.md. Apply migration 019 after the previous Database 022 update.

Current source checkpoint: see RELEASE-022.md for implemented changes, required SQL and remaining production/integration work.

# JioFlow CRM

A multi-business CRM with Supabase Auth/database and Vercel hosting. The main entry is index.html, with online.js and permission-checked RPC/server operations. The retained classic view sources provide the established visual design; their local authentication and mutation handlers are not used by the main application.

Run `npm run build`. Vercel serves dist and api/manage.mjs. Required server configuration: SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, SUPABASE_SECRET_KEY (server only), JIOFLOW_APP_ORIGIN. Apply numbered Supabase migrations in order.

See RELEASE-014.md and RELEASE-013.md for the current Agent login approval, Jio ID, password minimum, Creator controls, deployment instructions, checks and remaining limitations. Do not assume a visible retained control is connected: unavailable operations remain disabled and marked in the interface.

The app uses real Auth sessions and database row policies. New managed Agents do not need email verification; each new login requires approval. Owner/Admin verification is retained. Creator is the only role that creates/manages shops. Owners are restricted to their assigned business; Admins follow permissions; Agents cannot read profit or product costs.

Order entry, product/customer editing, follow-up notes and account/profile controls have database-backed operations. Courier provider booking/status synchronization, complete financial reporting, import processing, group distribution and settings persistence still require further implementation. No production-complete claim is made for those sections.
