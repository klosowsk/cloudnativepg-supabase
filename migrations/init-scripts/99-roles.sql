-- Final Role Password Configuration
-- Source: Official Supabase init-scripts/99-roles.sql
-- Modified for: Zalando/Spilo deployment (minimal changes)
--
-- This file will be copied to init-scripts/ at build time by prepare-init-scripts.sh
-- Execution: Phase 2 (Core Schema Initialization, runs last in init-scripts)
--
-- Sets passwords for Supabase service accounts
-- NOTE: In Zalando operator deployments, passwords are managed via Kubernetes secrets
--       The operator will override these passwords after bootstrap

-- NOTE: change to your own passwords for production environments
\set pgpass `echo "$POSTGRES_PASSWORD"`

ALTER USER authenticator WITH PASSWORD :'pgpass';
ALTER USER pgbouncer WITH PASSWORD :'pgpass';
ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_functions_admin WITH PASSWORD :'pgpass';
ALTER USER supabase_storage_admin WITH PASSWORD :'pgpass';
