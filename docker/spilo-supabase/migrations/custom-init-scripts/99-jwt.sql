-- JWT Configuration
-- Source: Official Supabase init-scripts/99-jwt.sql
-- Modified for: Zalando/Spilo deployment (added defaults for missing env vars)
--
-- This file will be copied to init-scripts/ at build time by prepare-init-scripts.sh
-- Execution: Phase 2 (Core Schema Initialization, runs late in init-scripts)
--
-- Sets JWT secret and expiration time as database-level settings
-- These are read by PostgREST and other Supabase services
--
-- NOTE: JWT_SECRET and JWT_EXP environment variables should be set via:
-- 1. Zalando manifest pod_environment_secret (recommended for production)
-- 2. Zalando manifest pod_environment_configmap (for non-sensitive defaults)
-- See manifests/supabase-postgres-*.yaml for configuration

\set jwt_secret `echo "$JWT_SECRET"`
\set jwt_exp `echo "$JWT_EXP"`

ALTER DATABASE postgres SET "app.settings.jwt_secret" TO :'jwt_secret';
ALTER DATABASE postgres SET "app.settings.jwt_exp" TO :'jwt_exp';
