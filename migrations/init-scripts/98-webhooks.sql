-- Supabase Edge Functions Database Webhooks Support
-- Source: Official Supabase init-scripts/98-webhooks.sql
-- Modified for: Zalando/Spilo deployment (matches official exactly)
--
-- This file will be copied to init-scripts/ at build time by prepare-init-scripts.sh
-- Execution: Phase 2 (Core Schema Initialization, runs before 99-*)
--
-- Creates the infrastructure for database webhooks (database triggers that make HTTP calls)
-- Requires pg_net extension to be enabled (via shared_preload_libraries)

BEGIN;

-- Create supabase_functions schema for Edge Functions integration
CREATE SCHEMA IF NOT EXISTS supabase_functions AUTHORIZATION supabase_admin;

GRANT USAGE ON SCHEMA supabase_functions TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions GRANT ALL ON TABLES TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions GRANT ALL ON FUNCTIONS TO postgres, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA supabase_functions GRANT ALL ON SEQUENCES TO postgres, anon, authenticated, service_role;

-- Migration tracking table
CREATE TABLE IF NOT EXISTS supabase_functions.migrations (
  version text PRIMARY KEY,
  inserted_at timestamptz NOT NULL DEFAULT NOW()
);

-- Initial migration marker
INSERT INTO supabase_functions.migrations (version) VALUES ('initial')
ON CONFLICT (version) DO NOTHING;

-- Hooks audit trail table
CREATE TABLE IF NOT EXISTS supabase_functions.hooks (
  id bigserial PRIMARY KEY,
  hook_table_id integer NOT NULL,
  hook_name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  request_id bigint
);

CREATE INDEX IF NOT EXISTS supabase_functions_hooks_request_id_idx
  ON supabase_functions.hooks USING btree (request_id);

CREATE INDEX IF NOT EXISTS supabase_functions_hooks_h_table_id_h_name_idx
  ON supabase_functions.hooks USING btree (hook_table_id, hook_name);

COMMENT ON TABLE supabase_functions.hooks IS 'Supabase Functions Hooks: Audit trail for triggered hooks.';

-- HTTP request trigger function
-- This is called by database triggers to make HTTP requests via pg_net
CREATE OR REPLACE FUNCTION supabase_functions.http_request()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = supabase_functions
  AS $function$
  DECLARE
    request_id bigint;
    payload jsonb;
    url text := TG_ARGV[0]::text;
    method text := TG_ARGV[1]::text;
    headers jsonb DEFAULT '{}'::jsonb;
    params jsonb DEFAULT '{}'::jsonb;
    timeout_ms integer DEFAULT 1000;
  BEGIN
    IF url IS NULL OR url = 'null' THEN
      RAISE EXCEPTION 'url argument is missing';
    END IF;

    IF method IS NULL OR method = 'null' THEN
      RAISE EXCEPTION 'method argument is missing';
    END IF;

    IF TG_ARGV[2] IS NULL OR TG_ARGV[2] = 'null' THEN
      headers = '{"Content-Type": "application/json"}'::jsonb;
    ELSE
      headers = TG_ARGV[2]::jsonb;
    END IF;

    IF TG_ARGV[3] IS NULL OR TG_ARGV[3] = 'null' THEN
      params = '{}'::jsonb;
    ELSE
      params = TG_ARGV[3]::jsonb;
    END IF;

    IF TG_ARGV[4] IS NULL OR TG_ARGV[4] = 'null' THEN
      timeout_ms = 1000;
    ELSE
      timeout_ms = TG_ARGV[4]::integer;
    END IF;

    CASE
      WHEN method = 'GET' THEN
        -- Check if pg_net is available
        IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
          RAISE EXCEPTION 'pg_net extension must be enabled for database webhooks';
        END IF;

        SELECT http_get INTO request_id FROM net.http_get(
          url,
          params,
          headers,
          timeout_ms
        );
      WHEN method = 'POST' THEN
        -- Check if pg_net is available
        IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
          RAISE EXCEPTION 'pg_net extension must be enabled for database webhooks';
        END IF;

        payload = jsonb_build_object(
          'old_record', OLD,
          'record', NEW,
          'type', TG_OP,
          'table', TG_TABLE_NAME,
          'schema', TG_TABLE_SCHEMA
        );

        SELECT http_post INTO request_id FROM net.http_post(
          url,
          payload,
          params,
          headers,
          timeout_ms
        );
      ELSE
        RAISE EXCEPTION 'method argument % is invalid', method;
    END CASE;

    INSERT INTO supabase_functions.hooks
      (hook_table_id, hook_name, request_id)
    VALUES
      (TG_RELID, TG_NAME, request_id);

    RETURN NEW;
  END
$function$;

COMMENT ON FUNCTION supabase_functions.http_request IS 'Trigger function to make HTTP requests via pg_net';

-- Ensure supabase_functions_admin user exists (may already be created by migrations)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_functions_admin') THEN
    CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
  END IF;
END $$;

-- Grant permissions to supabase_functions_admin
GRANT ALL PRIVILEGES ON SCHEMA supabase_functions TO supabase_functions_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA supabase_functions TO supabase_functions_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA supabase_functions TO supabase_functions_admin;

ALTER USER supabase_functions_admin SET search_path = "supabase_functions";

ALTER TABLE supabase_functions.migrations OWNER TO supabase_functions_admin;
ALTER TABLE supabase_functions.hooks OWNER TO supabase_functions_admin;
ALTER FUNCTION supabase_functions.http_request() OWNER TO supabase_functions_admin;

GRANT supabase_functions_admin TO postgres;

-- Grant execute permission to API roles
REVOKE ALL ON FUNCTION supabase_functions.http_request() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION supabase_functions.http_request() TO postgres, anon, authenticated, service_role;

-- Grant pg_net permissions if extension is already enabled
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    ALTER FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
    ALTER FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

    ALTER FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
    ALTER FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

    REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
    REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

    GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer)
      TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer)
      TO supabase_functions_admin, postgres, anon, authenticated, service_role;
  END IF;
END $$;

-- Event trigger to grant permissions when pg_net is enabled later
CREATE OR REPLACE FUNCTION extensions.grant_pg_net_access()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  ) THEN
    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    ALTER FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
    ALTER FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

    ALTER FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
    ALTER FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

    REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
    REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

    GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer)
      TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer)
      TO supabase_functions_admin, postgres, anon, authenticated, service_role;
  END IF;
END;
$$;

COMMENT ON FUNCTION extensions.grant_pg_net_access IS 'Grants access to pg_net when extension is created';

-- Create event trigger if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'issue_pg_net_access') THEN
    CREATE EVENT TRIGGER issue_pg_net_access
      ON ddl_command_end
      WHEN TAG IN ('CREATE EXTENSION')
      EXECUTE PROCEDURE extensions.grant_pg_net_access();
  END IF;
END $$;

-- Mark migrations as applied
INSERT INTO supabase_functions.migrations (version) VALUES ('20210809183423_update_grants')
ON CONFLICT (version) DO NOTHING;

COMMIT;

-- Usage Example:
--
-- 1. Enable pg_net (requires shared_preload_libraries):
--    CREATE EXTENSION pg_net WITH SCHEMA extensions;
--
-- 2. Create a webhook trigger on your table:
--    CREATE TRIGGER on_user_created
--      AFTER INSERT ON public.users
--      FOR EACH ROW
--      EXECUTE FUNCTION supabase_functions.http_request(
--        'https://your-function.supabase.co/user-created',
--        'POST',
--        '{"Content-Type": "application/json"}',
--        '{}',
--        1000
--      );
