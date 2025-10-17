-- JWT Configuration
-- Sets JWT settings at the database level
-- Source: supabase/docker/volumes/db/jwt.sql
-- These settings are used by PostgREST and other services

-- Note: JWT_SECRET and JWT_EXP environment variables should be set via:
-- 1. Zalando manifest pod_environment_secret (recommended for production)
-- 2. Zalando manifest pod_environment_configmap (for non-sensitive defaults)
-- See manifests/supabase-postgres-*.yaml for configuration

-- Set JWT secret from environment variable
\set jwt_secret `echo "${JWT_SECRET:-super-secret-jwt-token-with-at-least-32-characters-long}"`
-- Set JWT expiration from environment variable (defaults to 3600 seconds = 1 hour)
\set jwt_exp `echo "${JWT_EXP:-3600}"`

-- Apply settings to postgres database
ALTER DATABASE postgres SET "app.settings.jwt_secret" TO :'jwt_secret';
ALTER DATABASE postgres SET "app.settings.jwt_exp" TO :'jwt_exp';
