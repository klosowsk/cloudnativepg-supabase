-- Zalando/Spilo Pre-Initialization: Extensions
-- Phase 1 of 3-phase initialization process
--
-- Purpose: Create extensions schema and install core extensions BEFORE official
-- Supabase init scripts run. This ensures extensions are available when needed.
--
-- Why this runs first:
-- - Official Supabase assumes extensions schema exists
-- - uuid-ossp, pgcrypto needed by many schemas
-- - pg_stat_statements needed for Zalando monitoring
--
-- This file runs in Phase 1: Zalando Pre-Init (before init-scripts/)

BEGIN;

-- Create extensions schema
-- Official init-scripts will also try to create this, but that's OK (IF NOT EXISTS)
CREATE SCHEMA IF NOT EXISTS extensions;

-- Core extensions required by Supabase
-- These must exist before other schemas are created
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- HTTP client extension for webhooks and edge functions
-- Required for database webhooks and async HTTP requests
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Monitoring extension for Zalando/Patroni
-- Required for query performance monitoring in Kubernetes
CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;

-- Grant usage to postgres user
-- API roles (anon, authenticated, service_role) will be granted access later
-- in the official 00000000000000-initial-schema.sql
GRANT USAGE ON SCHEMA extensions TO postgres;

COMMIT;

-- Log completion
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Zalando Extensions Setup Complete';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Extensions schema: created';
  RAISE NOTICE 'Core extensions: uuid-ossp, pgcrypto, pg_net, pg_stat_statements';
  RAISE NOTICE '';
END $$;
