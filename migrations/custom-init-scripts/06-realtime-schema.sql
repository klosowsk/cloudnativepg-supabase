-- Realtime Schema Initialization
-- Creates the _realtime schema for Supabase Realtime service
-- Source: supabase/docker/volumes/db/realtime.sql
-- Note: Realtime service will create its own tables via Ecto migrations

-- Create _realtime schema for internal Realtime tables
CREATE SCHEMA IF NOT EXISTS _realtime;
ALTER SCHEMA _realtime OWNER TO supabase_admin;

-- Grant permissions
GRANT USAGE ON SCHEMA _realtime TO postgres;
GRANT ALL ON SCHEMA _realtime TO supabase_admin;
