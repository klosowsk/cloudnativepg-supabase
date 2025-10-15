-- Enable pg_stat_statements for query performance monitoring
-- Source: supabase-postgres/ansible/files/stat_extension.sql

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;
