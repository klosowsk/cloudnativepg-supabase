-- Supabase Utility Database
-- Source: Official Supabase migrations/97-_supabase.sql
-- Modified for: Zalando/Spilo deployment (owner changed to supabase_admin)
--
-- This file will be copied to migrations/ at build time by prepare-init-scripts.sh
-- Execution: Phase 3 (Late-stage migrations, runs after all timestamped migrations)
--
-- Creates the _supabase database used by Supabase platform services for:
-- - Internal state coordination
-- - Service-to-service communication
-- - Administrative operations separate from user data
--
-- Official uses: \set pguser `echo "$POSTGRES_USER"`
--                CREATE DATABASE _supabase WITH OWNER :pguser;
-- Zalando uses: CREATE DATABASE _supabase WITH OWNER supabase_admin;
-- Reason: In Zalando, supabase_admin is the primary admin role, not postgres

CREATE DATABASE _supabase WITH OWNER supabase_admin;
