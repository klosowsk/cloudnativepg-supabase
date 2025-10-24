-- PgBouncer Authentication Setup
-- Source: Official Supabase init-scripts/00-schema.sql
-- Modified for: Zalando/Spilo deployment (minimal changes)
--
-- This file will be copied to init-scripts/ at build time by prepare-init-scripts.sh
-- Execution: Phase 2 (Core Schema Initialization)
--
-- Creates the pgbouncer user and schema with the auth function that PgBouncer
-- uses to authenticate database connections.

CREATE USER pgbouncer;

REVOKE ALL PRIVILEGES ON SCHEMA public FROM pgbouncer;

CREATE SCHEMA pgbouncer AUTHORIZATION pgbouncer;

CREATE OR REPLACE FUNCTION pgbouncer.get_auth(p_usename TEXT)
RETURNS TABLE(username TEXT, password TEXT) AS
$$
BEGIN
    RAISE WARNING 'PgBouncer auth request: %', p_usename;

    RETURN QUERY
    SELECT usename::TEXT, passwd::TEXT FROM pg_catalog.pg_shadow
    WHERE usename = p_usename;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION pgbouncer.get_auth(p_usename TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pgbouncer.get_auth(p_usename TEXT) TO pgbouncer;
