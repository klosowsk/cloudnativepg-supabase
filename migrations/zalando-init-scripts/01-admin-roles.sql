-- Zalando/Spilo Pre-Initialization: Admin Roles
-- Phase 1 of 3-phase initialization process
--
-- Purpose: Create Supabase ADMIN roles that must exist BEFORE official init scripts run.
-- These are roles that the official Supabase Docker image creates via entrypoint,
-- but Zalando/Spilo needs them created here during Patroni bootstrap.
--
-- IMPORTANT: This file creates ONLY admin/service roles.
-- API roles (anon, authenticated, service_role, authenticator) are created by
-- official Supabase in init-scripts/00000000000000-initial-schema.sql
--
-- Why separate from official scripts:
-- - Official assumes supabase_admin exists (created by Docker entrypoint)
-- - Zalando/Patroni bootstrap happens before operator creates users
-- - Creating these early prevents "role does not exist" errors
-- - Zalando operator will later update passwords and attributes
--
-- This file runs in Phase 1: Zalando Pre-Init (before init-scripts/)

BEGIN;

-- ============================================================================
-- ADMIN ROLES (created here, not in official scripts)
-- ============================================================================

-- Core superuser for all Supabase operations
-- NOTE: We create it WITHOUT superuser here, and the official init-scripts will
-- promote it to superuser via: alter user supabase_admin with superuser...
-- This matches the official Supabase flow where the role exists before promotion.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin') THEN
    CREATE ROLE supabase_admin WITH LOGIN;
    RAISE NOTICE 'Created role: supabase_admin (will be promoted to superuser in Phase 2)';
  ELSE
    RAISE NOTICE 'Role already exists: supabase_admin';
  END IF;
END $$;

-- ============================================================================
-- SERVICE-SPECIFIC ADMIN ROLES (NOT created here - created by official scripts)
-- ============================================================================
-- The following service admin roles are created by official Supabase:
--   - supabase_auth_admin: init-scripts/00000000000001-auth-schema.sql
--   - supabase_storage_admin: init-scripts/00000000000002-storage-schema.sql
--   - supabase_functions_admin: init-scripts/98-webhooks.sql (custom)
-- DO NOT create them here to avoid conflicts!
-- ============================================================================

-- ============================================================================
-- ROLES NOT CREATED HERE (created by official Supabase init-scripts)
-- ============================================================================
-- The following roles are created by official Supabase and must NOT be
-- created here to avoid "role already exists" errors:
--
-- From init-scripts/00000000000000-initial-schema.sql:
--   - supabase_replication_admin (line 11)
--   - supabase_read_only_user (line 14)
--
-- From init-scripts/00000000000003-post-setup.sql:
--   - dashboard_user
--
-- These will be created in Phase 2 by the official scripts.
-- ============================================================================

COMMIT;

-- ============================================================================
-- API ROLES (NOT created here - created by official init-scripts)
-- ============================================================================
-- The following roles are created by official Supabase in
-- init-scripts/00000000000000-initial-schema.sql:
-- - anon (nologin, noinherit)
-- - authenticated (nologin, noinherit)
-- - service_role (nologin, noinherit, bypassrls)
-- - authenticator (noinherit, login)
--
-- DO NOT duplicate these here to avoid conflicts!
-- ============================================================================

-- Summary
DO $$
DECLARE
  admin_role_count INTEGER;
BEGIN
  -- Only count supabase_admin (the only role we create)
  SELECT COUNT(*) INTO admin_role_count
  FROM pg_roles
  WHERE rolname = 'supabase_admin';

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Zalando Pre-Initialization Complete';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Core superuser role created: supabase_admin';
  RAISE NOTICE '';
  RAISE NOTICE 'Next (Phase 2 - Official init-scripts will create):';
  RAISE NOTICE '  - Service admins: supabase_auth_admin, supabase_storage_admin, supabase_functions_admin';
  RAISE NOTICE '  - Replication: supabase_replication_admin';
  RAISE NOTICE '  - Read-only: supabase_read_only_user';
  RAISE NOTICE '  - API roles: anon, authenticated, service_role, authenticator';
  RAISE NOTICE '  - Dashboard: dashboard_user';
  RAISE NOTICE '';
  RAISE NOTICE 'Note: Zalando operator will update these roles with passwords';
  RAISE NOTICE '';
END $$;
