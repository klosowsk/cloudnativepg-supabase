-- PgBouncer authentication function (initial version)
-- This creates the base function that will be updated by migration 20250417190610_update_pgbouncer_get_auth.sql
-- Source: supabase-postgres/ansible/files/pgbouncer_config/pgbouncer_auth_schema.sql

CREATE OR REPLACE FUNCTION pgbouncer.get_auth(p_usename TEXT)
RETURNS TABLE(username TEXT, password TEXT) AS
$$
BEGIN
    RAISE DEBUG 'PgBouncer auth request: %', p_usename;

    RETURN QUERY
    SELECT usename::TEXT, passwd::TEXT FROM pg_catalog.pg_shadow
    WHERE usename = p_usename;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Permissions will be set by migration 20250312095419_pgbouncer_ownership.sql
