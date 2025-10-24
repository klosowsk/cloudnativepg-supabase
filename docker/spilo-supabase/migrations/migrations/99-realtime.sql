-- Realtime Schema in postgres Database
-- Source: Official Supabase migrations/99-realtime.sql
-- Modified for: Zalando/Spilo deployment (owner changed to supabase_admin)
--
-- This file will be copied to migrations/ at build time by prepare-init-scripts.sh
-- Execution: Phase 3 (Late-stage migrations, runs after all timestamped migrations)
--
-- Creates the _realtime schema for internal Realtime service tables
-- Note: Realtime service will create its own tables via Ecto migrations
--
-- Official uses: \set pguser `echo "$POSTGRES_USER"`
--                alter schema _realtime owner to :pguser;
-- Zalando uses: alter schema _realtime owner to supabase_admin;
-- Reason: In Zalando, supabase_admin is the primary admin role, not postgres

create schema if not exists _realtime;
alter schema _realtime owner to supabase_admin;
