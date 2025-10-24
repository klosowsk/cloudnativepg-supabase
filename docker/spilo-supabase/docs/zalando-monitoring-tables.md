# Zalando Spilo Monitoring Tables

## Overview

Spilo automatically creates monitoring tables and views in the `public` schema during initialization. These are part of Zalando's production-grade PostgreSQL monitoring infrastructure and provide SQL-queryable access to PostgreSQL logs and authentication failures.

## postgres_log Tables

### Purpose
Foreign tables that provide SQL access to PostgreSQL CSV logs using the `file_fdw` extension.

### Structure
- **Base table**: `public.postgres_log` (parent table with CHECK constraint to prevent direct inserts)
- **Daily partitions**: `postgres_log_0` through `postgres_log_6` (one per weekday)
  - 0 = Sunday
  - 1 = Monday
  - 2 = Tuesday
  - 3 = Wednesday
  - 4 = Thursday
  - 5 = Friday
  - 6 = Saturday

### Schema
```sql
CREATE TABLE public.postgres_log (
    log_time timestamp(3) with time zone,
    user_name text,
    database_name text,
    process_id integer,
    connection_from text,
    session_id text NOT NULL,
    session_line_num bigint NOT NULL,
    command_tag text,
    session_start_time timestamp with time zone,
    virtual_transaction_id text,
    transaction_id bigint,
    error_severity text,
    sql_state_code text,
    message text,
    detail text,
    hint text,
    internal_query text,
    internal_query_pos integer,
    context text,
    query text,
    query_pos integer,
    location text,
    application_name text,
    backend_type text,        -- PG 13+
    leader_pid integer,       -- PG 14+
    query_id bigint,          -- PG 14+
    CONSTRAINT postgres_log_check CHECK (false) NO INHERIT
);
```

### Implementation
Each daily partition is a **foreign table** pointing to PostgreSQL's CSV log files:
```sql
CREATE FOREIGN TABLE postgres_log_0 ()
  INHERITS (public.postgres_log)
  SERVER pglog
  OPTIONS (filename '/var/log/postgresql/postgresql-0.csv', format 'csv');
```

### Access Control
- Granted to `admin` role for SELECT
- Used by `robot_zmon` role for monitoring

### Usage Examples
```sql
-- View all logs from today
SELECT log_time, user_name, database_name, message
FROM public.postgres_log
WHERE log_time > CURRENT_DATE
ORDER BY log_time DESC;

-- Find errors in last hour
SELECT log_time, error_severity, message, detail
FROM public.postgres_log
WHERE log_time > NOW() - INTERVAL '1 hour'
  AND error_severity IN ('ERROR', 'FATAL', 'PANIC')
ORDER BY log_time DESC;

-- Check slow queries
SELECT log_time, user_name, database_name,
       substring(message from 'duration: ([0-9.]+) ms') as duration_ms,
       query
FROM public.postgres_log
WHERE message LIKE 'duration:%'
ORDER BY duration_ms DESC
LIMIT 20;
```

## failed_authentication Views

### Purpose
Security monitoring views that track failed login attempts by filtering postgres_log for authentication failures.

### Structure
- **Daily views**: `failed_authentication_0` through `failed_authentication_7`
  - Note: Both 0 and 7 exist for Sunday (compatibility)
  - Views 1-6 map to Monday-Saturday

### Implementation
Each view filters the corresponding postgres_log partition:
```sql
CREATE VIEW public.failed_authentication_0 WITH (security_barrier) AS
SELECT *
FROM public.postgres_log_0
WHERE command_tag = 'authentication'
  AND error_severity = 'FATAL';
```

### Security Features
- Created with `security_barrier` option to prevent information leakage
- Owned by `postgres` superuser
- Granted to `robot_zmon` for monitoring

### Access Control
```sql
ALTER VIEW public.failed_authentication_0 OWNER TO postgres;
GRANT SELECT ON TABLE public.failed_authentication_0 TO robot_zmon;
```

### Usage Examples
```sql
-- View all failed login attempts today
SELECT log_time, user_name, database_name, connection_from, message
FROM public.failed_authentication_0  -- Adjust for day of week
ORDER BY log_time DESC;

-- Count failed attempts by user
SELECT user_name, COUNT(*) as failed_attempts
FROM public.failed_authentication_0
GROUP BY user_name
ORDER BY failed_attempts DESC;

-- Detect brute force attacks (multiple failures from same IP)
SELECT connection_from, COUNT(*) as attempts,
       MIN(log_time) as first_attempt,
       MAX(log_time) as last_attempt
FROM public.failed_authentication_0
GROUP BY connection_from
HAVING COUNT(*) > 5
ORDER BY attempts DESC;
```

## Integration with ZMON

These tables are designed for Zalando's ZMON (Zalando Monitoring) system:
- The `robot_zmon` role has read access to both postgres_log and failed_authentication views
- ZMON queries these tables periodically for alerting and dashboards
- Partitioning by weekday allows efficient queries and log rotation

## Compatibility with Supabase

These monitoring tables **do not conflict** with Supabase:
- ✅ Different schemas and purposes (monitoring vs application)
- ✅ Read-only foreign tables don't impact database performance
- ✅ Provide valuable debugging and security monitoring
- ✅ No overlap with Supabase's built-in monitoring

## Configuration

### PostgreSQL logging must be configured for CSV output:
```yaml
# Required postgresql.conf settings (already set in Spilo)
log_destination = 'csvlog'
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%w.csv'  # %w = day of week (0-6)
log_rotation_age = 1d
log_rotation_size = 0
log_truncate_on_rotation = on
```

### What gets logged:
All PostgreSQL log messages including:
- Connection attempts (successful and failed)
- Authentication events
- Query errors
- Slow queries (if log_min_duration_statement is set)
- DDL statements (if log_statement = 'ddl' or 'all')
- Checkpoints, autovacuum, etc.

## Maintenance

### Log Rotation
- Logs rotate daily based on weekday
- Old logs are truncated when the same weekday comes around (7-day retention)
- Controlled by `log_truncate_on_rotation = on`

### Disk Space
- Each day's CSV log is separate
- Maximum 7 days of logs retained
- Monitor `/var/log/postgresql/` for disk usage

### Cleanup
If you want to disable these tables, modify the Spilo image or remove them post-initialization:
```sql
-- Drop views
DROP VIEW IF EXISTS public.failed_authentication_0;
-- ... repeat for 1-7

-- Drop foreign tables
DROP FOREIGN TABLE IF EXISTS public.postgres_log_0;
-- ... repeat for 1-6

-- Drop base table
DROP TABLE IF EXISTS public.postgres_log;

-- Drop foreign server
DROP SERVER IF EXISTS pglog CASCADE;

-- Drop extension (if not needed elsewhere)
DROP EXTENSION IF EXISTS file_fdw;
```

**Note**: Not recommended unless you have alternative logging/monitoring in place.

## References

- [PostgreSQL file_fdw Documentation](https://www.postgresql.org/docs/current/file-fdw.html)
- [PostgreSQL CSV Log Format](https://www.postgresql.org/docs/current/runtime-config-logging.html#RUNTIME-CONFIG-LOGGING-CSVLOG)
- [Zalando Spilo Documentation](https://github.com/zalando/spilo)
- [ZMON Monitoring](https://github.com/zalando/zmon)
