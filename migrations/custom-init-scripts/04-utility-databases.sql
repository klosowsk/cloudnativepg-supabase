-- Supabase Utility Databases
-- Source: supabase/docker/volumes/db/_supabase.sql
-- These databases are used by Supabase services for internal coordination and state management

-- Create _supabase database for internal Supabase services
-- Used by Supabase platform services for:
-- - Internal state coordination
-- - Service-to-service communication
-- - Administrative operations separate from user data
CREATE DATABASE _supabase WITH OWNER supabase_admin;

COMMENT ON DATABASE _supabase IS 'Supabase internal database for platform services coordination';

-- Note: Additional internal schemas (_realtime, _analytics) are created by
-- their respective Supabase services when they connect for the first time.
-- We create the database here so it's available from the start.
