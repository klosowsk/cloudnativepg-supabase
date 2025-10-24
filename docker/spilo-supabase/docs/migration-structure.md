# Migration Structure

Supabase initialization runs in **3 phases** during Patroni cluster bootstrap.

## Overview

```
Bootstrap Flow:
1. Patroni initializes PostgreSQL
2. Spilo runs post_init.sh callbacks
3. Our supabase_post_init.sh executes 3 phases
4. Patroni completes post_bootstrap
5. Cluster is ready
```

## Phase 1: Zalando Pre-Initialization

**Location**: `migrations/zalando-init-scripts/`
**Runs as**: `postgres` (system superuser)
**Purpose**: Create extensions and admin roles BEFORE official Supabase scripts

### What it does:
- Creates `extensions` schema
- Installs core extensions:
  - `uuid-ossp` - UUID generation
  - `pgcrypto` - Cryptographic functions
  - `pg_net` - HTTP client (requires `shared_preload_libraries` config)
  - `pg_stat_statements` - Query statistics
- Creates `supabase_admin` role (without superuser, promoted in Phase 2)

### Why it runs first:
- Official Supabase scripts assume extensions schema exists
- Extensions must be installed by system superuser
- Ensures `supabase_admin` exists before promotion

## Phase 2: Core Schema Initialization

**Location**: `migrations/init-scripts/`
**Runs as**: `supabase_admin` (application superuser)
**Purpose**: Official Supabase schemas + custom Zalando modifications

### Official init-scripts (from Supabase):
- `00000000000000-initial-schema.sql` - Core setup, promotes `supabase_admin` to superuser
- `00000000000001-auth-schema.sql` - Authentication schema
- `00000000000002-storage-schema.sql` - File storage schema
- `00000000000003-post-setup.sql` - Event triggers, pg_cron, pg_net permissions

### Custom init-scripts (Zalando-specific):
- `00-schema.sql` - PgBouncer authentication setup
- `98-webhooks.sql` - Database webhooks (requires pg_net)
- `99-jwt.sql` - JWT secret configuration
- `99-roles.sql` - Service-specific admin roles

### Schemas created:
- `auth` - User authentication and sessions
- `storage` - File metadata and buckets
- `realtime` - WebSocket subscriptions
- `pgbouncer` - Connection pooler authentication

### Roles created:
- `supabase_admin` (promoted to SUPERUSER)
- `anon` - Anonymous API access
- `authenticated` - Authenticated API access
- `service_role` - Service-level access (bypasses RLS)
- `authenticator` - API gateway role
- Service admins: `supabase_auth_admin`, `supabase_storage_admin`, etc.

## Phase 3: Incremental Migrations

**Location**: `migrations/migrations/`
**Runs as**: `supabase_admin` (application superuser)
**Purpose**: Timestamped migrations + custom late-stage setup

### Official migrations (40+ files):
Timestamped migrations from Supabase (e.g., `20220317095840_pg_graphql.sql`)
- GraphQL schema and permissions
- Realtime subscriptions
- Vault secrets management
- Storage policies and permissions
- Auth improvements
- Extension updates

### Custom migrations (Zalando-specific):
- `97-_supabase.sql` - Creates `_supabase` utility database
- `99-logs.sql` - Analytics schema (`_analytics`)
- `99-pooler.sql` - Connection pooler schema (`_supavisor`)
- `99-realtime.sql` - Realtime internal schema (`_realtime`)

### Skipped migrations:
- `10000000000000_demote-postgres.sql` - Skipped because Patroni requires `postgres` to remain superuser for cluster management

## Schema Ownership

### Supabase Schemas (owned by `supabase_admin`):
- `auth` - Authentication
- `storage` - File storage
- `supabase_functions` - Edge Functions
- `_realtime` - Realtime internals
- `vault` - Secrets vault
- `graphql`, `graphql_public` - GraphQL API
- `realtime` - Realtime public API

### System Schemas (owned by `postgres`):
- `extensions` - PostgreSQL extensions
- `public` - Default public schema

### Spilo Schemas (owned by `postgres`):
- `cron` - pg_cron scheduled jobs
- `metric_helpers` - Spilo monitoring
- `user_management` - Spilo user management
- `zmon_utils` - Spilo ZMON monitoring

### Special Schemas:
- `pgbouncer` (owned by `pgbouncer`) - Connection pooler auth

**Note**: Both `postgres` and `supabase_admin` are superusers, so ownership differences have no functional impact on permissions.

## Schema Comparison vs Official Supabase

### Identical Core Features ✅
- All authentication, storage, realtime schemas
- All Supabase roles and permissions
- All core Supabase extensions
- GraphQL API schemas
- Vault secrets management

### Additional Production Features (Spilo/Zalando) ✅
- **`pg_cron`** - Scheduled job support
- **`metric_helpers`**, **`zmon_utils`** - Monitoring and metrics
- **`user_management`** - User management features
- **`pg_auth_mon`**, **`pg_stat_kcache`** - Additional monitoring extensions
- **`file_fdw`**, **`plpython3u`** - Extended functionality

### Verification

Run the comparison script to verify schema parity:

```bash
./scripts/compare-schemas.sh
```

This compares your custom image against the official `supabase/postgres` container.

## Key Differences from Official Supabase

### 1. Initialization Process
- **Official**: Docker entrypoint runs init-scripts then migrations sequentially
- **Zalando**: Patroni bootstrap callback runs 3-phase process with proper role separation

### 2. postgres Role
- **Official**: Demoted to non-superuser after initialization
- **Zalando**: Remains superuser (required by Patroni for cluster management)

### 3. Ownership
- **Official**: Everything owned by `:pguser` variable (typically `postgres` in official, `supabase_admin` after demotion)
- **Zalando**: Explicit separation - system schemas owned by `postgres`, application schemas by `supabase_admin`

### 4. Additional Features
- **Official**: Pure Supabase
- **Zalando**: Includes production monitoring, scheduled jobs, HA features

## Regenerating Migrations

To update to a new Supabase version:

```bash
# Edit scripts/prepare-init-scripts.sh and update SUPABASE_VERSION
vim scripts/prepare-init-scripts.sh

# Regenerate migration files
./scripts/prepare-init-scripts.sh

# Rebuild image
./build.sh
```

This fetches the latest migrations from the official Supabase postgres repository and merges them with custom Zalando-specific files.

## Troubleshooting

### Extensions not installed
Check Phase 1 logs:
```bash
kubectl logs supabase-db-0 -n supabase | grep "Phase 1"
```

### Roles missing
Check Phase 2 logs:
```bash
kubectl logs supabase-db-0 -n supabase | grep "Phase 2"
```

### Schema missing
Check Phase 3 logs:
```bash
kubectl logs supabase-db-0 -n supabase | grep "Phase 3"
```

