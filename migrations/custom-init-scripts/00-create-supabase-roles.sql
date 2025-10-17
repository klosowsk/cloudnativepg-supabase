-- Supabase Roles Pre-Creation Script
--
-- Purpose: Create all required Supabase roles BEFORE running init scripts.
-- This solves the timing issue where Zalando operator creates users AFTER
-- Patroni's post_init script runs, causing "role does not exist" errors.
--
-- The Zalando operator will later:
-- 1. Detect these roles already exist
-- 2. Update their attributes to match the manifest
-- 3. Set proper passwords and store them in K8s secrets
--
-- This approach is safe and idempotent. Roles are created with appropriate
-- attributes, but the operator has final control over passwords and privileges.

BEGIN;

-- Core admin role (superuser for Supabase operations)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin') THEN
    CREATE ROLE supabase_admin WITH SUPERUSER CREATEDB CREATEROLE REPLICATION BYPASSRLS LOGIN;
    RAISE NOTICE 'Created role: supabase_admin';
  ELSE
    RAISE NOTICE 'Role already exists: supabase_admin';
  END IF;
END $$;

-- Service-specific admin roles
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    CREATE ROLE supabase_auth_admin WITH CREATEROLE LOGIN;
    RAISE NOTICE 'Created role: supabase_auth_admin';
  ELSE
    RAISE NOTICE 'Role already exists: supabase_auth_admin';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_storage_admin') THEN
    CREATE ROLE supabase_storage_admin WITH CREATEROLE LOGIN;
    RAISE NOTICE 'Created role: supabase_storage_admin';
  ELSE
    RAISE NOTICE 'Role already exists: supabase_storage_admin';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_functions_admin') THEN
    CREATE ROLE supabase_functions_admin WITH CREATEROLE LOGIN;
    RAISE NOTICE 'Created role: supabase_functions_admin';
  ELSE
    RAISE NOTICE 'Role already exists: supabase_functions_admin';
  END IF;
END $$;

-- API roles (nologin roles used by PostgREST)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
    RAISE NOTICE 'Created role: anon';
  ELSE
    RAISE NOTICE 'Role already exists: anon';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
    RAISE NOTICE 'Created role: authenticated';
  ELSE
    RAISE NOTICE 'Role already exists: authenticated';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
    RAISE NOTICE 'Created role: service_role';
  ELSE
    RAISE NOTICE 'Role already exists: service_role';
  END IF;
END $$;

-- Authenticator role (main connection role that switches to anon/authenticated/service_role)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator NOINHERIT LOGIN;
    GRANT anon TO authenticator;
    GRANT authenticated TO authenticator;
    GRANT service_role TO authenticator;
    RAISE NOTICE 'Created role: authenticator with grants';
  ELSE
    -- Ensure grants are present even if role exists
    GRANT anon TO authenticator;
    GRANT authenticated TO authenticator;
    GRANT service_role TO authenticator;
    RAISE NOTICE 'Role already exists: authenticator (grants verified)';
  END IF;
END $$;

-- Replication and ETL roles
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_replication_admin') THEN
    CREATE ROLE supabase_replication_admin WITH LOGIN REPLICATION;
    RAISE NOTICE 'Created role: supabase_replication_admin';
  ELSE
    RAISE NOTICE 'Role already exists: supabase_replication_admin';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_etl_admin') THEN
    CREATE ROLE supabase_etl_admin WITH LOGIN REPLICATION;
    RAISE NOTICE 'Created role: supabase_etl_admin';
  ELSE
    RAISE NOTICE 'Role already exists: supabase_etl_admin';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_read_only_user') THEN
    CREATE ROLE supabase_read_only_user WITH LOGIN BYPASSRLS;
    RAISE NOTICE 'Created role: supabase_read_only_user';
  ELSE
    RAISE NOTICE 'Role already exists: supabase_read_only_user';
  END IF;
END $$;

-- Dashboard user (referenced in some migrations)
-- This is an optional role used by Supabase dashboard/internal tooling
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dashboard_user') THEN
    CREATE ROLE dashboard_user LOGIN;
    RAISE NOTICE 'Created role: dashboard_user';
  ELSE
    RAISE NOTICE 'Role already exists: dashboard_user';
  END IF;
END $$;

COMMIT;

-- Summary
DO $$
DECLARE
  role_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO role_count
  FROM pg_roles
  WHERE rolname IN (
    'supabase_admin', 'supabase_auth_admin', 'supabase_storage_admin',
    'supabase_functions_admin', 'anon', 'authenticated', 'service_role',
    'authenticator', 'supabase_replication_admin', 'supabase_etl_admin',
    'supabase_read_only_user', 'dashboard_user'
  );

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Supabase Roles Pre-Creation Complete';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Total Supabase roles present: %', role_count;
  RAISE NOTICE '';
  RAISE NOTICE 'Note: Zalando operator will update these roles with';
  RAISE NOTICE 'proper passwords and attributes from the manifest.';
  RAISE NOTICE '';
END $$;
