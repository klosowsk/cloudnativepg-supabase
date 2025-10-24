-- Fix pooler.user_lookup Function Created by Zalando Postgres Operator
-- Phase 1 of 3-phase initialization process
--
-- Purpose: Add missing SET search_path to pooler.user_lookup function that
-- is automatically created by the Zalando Postgres Operator when connection
-- pooling is enabled.
--
-- Root Cause: Zalando Postgres Operator's database.go:76-94 has a hardcoded
-- SQL template that creates pooler.user_lookup as SECURITY DEFINER but does
-- NOT include SET search_path, causing Supabase security warnings.
--
-- This file runs in Phase 1: Zalando Pre-Init (before init-scripts/)
-- The operator creates pooler.user_lookup in every database when pooling is
-- enabled, so we fix it here to ensure it has proper search_path security.

DO $$
BEGIN
    -- Check if pooler schema exists (created by operator)
    IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'pooler') THEN

        RAISE NOTICE 'Found pooler schema, fixing pooler.user_lookup function...';

        -- Recreate function with SET search_path
        -- We use CREATE OR REPLACE to be idempotent
        CREATE OR REPLACE FUNCTION pooler.user_lookup(
            in i_username text, out uname text, out phash text)
        RETURNS record AS $func$
        BEGIN
            SELECT usename, passwd FROM pg_catalog.pg_shadow
            WHERE usename = i_username INTO uname, phash;
            RETURN;
        END;
        $func$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

        -- Restore grants (operator sets these but CREATE OR REPLACE might reset them)
        REVOKE ALL ON FUNCTION pooler.user_lookup(text) FROM public;

        -- Grant to pooler role if it exists
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pooler') THEN
            GRANT EXECUTE ON FUNCTION pooler.user_lookup(text) TO pooler;
            GRANT USAGE ON SCHEMA pooler TO pooler;
            RAISE NOTICE 'Granted pooler.user_lookup to pooler role';
        ELSE
            RAISE NOTICE 'Pooler role not found, skipping grants';
        END IF;

        RAISE NOTICE '✅ Fixed pooler.user_lookup to include SET search_path';

    ELSE
        RAISE NOTICE '⏭️  Pooler schema not found, skipping pooler.user_lookup fix';
        RAISE NOTICE '   (This is normal if connection pooling is not enabled)';
    END IF;
END $$;

-- Log completion
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Pooler Security Fix Complete';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'If pooler schema was found:';
  RAISE NOTICE '  - pooler.user_lookup now has SET search_path = ''''';
  RAISE NOTICE '  - Supabase security warning resolved';
  RAISE NOTICE '';
END $$;
