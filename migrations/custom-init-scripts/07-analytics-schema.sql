-- Analytics and Pooler Schema Initialization
-- Creates schemas in _supabase database for internal Supabase services
-- Sources:
--   - supabase/docker/volumes/db/logs.sql (_analytics)
--   - supabase/docker/volumes/db/pooler.sql (_supavisor)

-- Connect to _supabase database
\c _supabase

-- Create _analytics schema for Logflare/Analytics service
CREATE SCHEMA IF NOT EXISTS _analytics;
ALTER SCHEMA _analytics OWNER TO supabase_admin;
GRANT USAGE ON SCHEMA _analytics TO postgres;
GRANT ALL ON SCHEMA _analytics TO supabase_admin;

-- Create _supavisor schema for connection pooler (Supavisor)
CREATE SCHEMA IF NOT EXISTS _supavisor;
ALTER SCHEMA _supavisor OWNER TO supabase_admin;
GRANT USAGE ON SCHEMA _supavisor TO postgres;
GRANT ALL ON SCHEMA _supavisor TO supabase_admin;

-- Set default search_path for _supabase database to include _analytics schema
-- This allows Ecto migrations to find the correct schema for schema_migrations table
ALTER DATABASE _supabase SET search_path TO _analytics, public;

-- Switch back to postgres database
\c postgres
