-- PgBouncer authentication schema setup
-- This must run before migrations that reference pgbouncer schema
-- Source: supabase-postgres/ansible/files/pgbouncer_config/pgbouncer_auth_schema.sql

-- Create pgbouncer schema
CREATE SCHEMA IF NOT EXISTS pgbouncer;

-- Note: The pgbouncer user and get_auth function are created/updated by later migrations
-- This script only ensures the schema exists before those migrations run
