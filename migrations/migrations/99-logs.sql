-- Analytics Schema in _supabase Database
-- Source: Official Supabase migrations/99-logs.sql
-- Modified for: Zalando/Spilo deployment (owner changed to supabase_admin)
--
-- This file will be copied to migrations/ at build time by prepare-init-scripts.sh
-- Execution: Phase 3 (Late-stage migrations, runs after all timestamped migrations)
--
-- Creates the _analytics schema for Logflare/Analytics service
--
-- Official uses: \set pguser `echo "$POSTGRES_USER"`
--                alter schema _analytics owner to :pguser;
-- Zalando uses: alter schema _analytics owner to supabase_admin;
-- Reason: In Zalando, supabase_admin is the primary admin role, not postgres

\c _supabase
create schema if not exists _analytics;
alter schema _analytics owner to supabase_admin;
\c postgres
