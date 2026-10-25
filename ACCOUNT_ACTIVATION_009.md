# Account activation update 009

1. In Supabase SQL Editor run supabase/migrations/006_account_activation.sql once, after 005.
2. Upload all extracted ZIP contents to the existing GitHub repository root, replacing matching paths. Keep every other file.
3. Wait for Vercel Ready and refresh the main site.

Creator can activate/deactivate non-Creator accounts after a confirmation. Deactivation blocks existing and new JioFlow access without removing assignments, ownership or history. Reactivation requires a fresh sign-in and preserves Agent approval rules. Self/Creator targets and non-Creator actors are rejected by the database. UI session checks detect revocation within 30 seconds or on focus; database access is blocked immediately.

Reset email now displays a confirmation that a reset was requested. This is not proof of delivery. SMTP and mail-provider setup remain external requirements.

This release completes account activation only. The remaining order/import/courier/reporting integrations are not represented as completed. Creator sign-in has no one-device restriction; email/password are verified by Supabase Auth. Legacy browser-local passwords do not automatically become Supabase credentials.
