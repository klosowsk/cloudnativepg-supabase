# Architecture Overview

## What's Included

Spilo Supabase packages the complete Supabase database stack from the [official Supabase repositories](https://github.com/supabase/postgres) into a production-ready PostgreSQL image for Kubernetes.

## Supabase Schemas

All standard Supabase schemas are automatically created on first boot:

- **`auth`** - User authentication, sessions, MFA, identity providers
- **`storage`** - File storage buckets, objects, permissions
- **`realtime`** - WebSocket subscriptions and filters
- **`vault`** - Encrypted secrets storage
- **`extensions`** - PostgreSQL extensions namespace
- **`supabase_functions`** - Edge Functions and webhooks
- **`graphql_public`** - Public GraphQL schema
- **`pgbouncer`** - Connection pooler authentication
- **`public`** - Default schema for user data
- Internal schemas: `_analytics`, `_realtime`

## PostgreSQL Extensions

### Core Supabase Extensions

| Extension | Purpose |
|-----------|---------|
| `pg_net` | Async HTTP requests (Edge Functions) |
| `pgsodium` | Modern encryption library |
| `supabase_vault` | Secrets management |
| `pg_graphql` | GraphQL API support |
| `supautils` | Supabase utility functions |
| `pgvector` | Vector similarity search (AI/embeddings) |
| `pg_tle` | Trusted Language Extensions |
| `pgjwt` | JWT token support |
| `pg_jsonschema` | JSON schema validation |
| `wrappers` | Foreign Data Wrapper collections |
| `pgmq` | Message queue |

### Additional Extensions

| Extension | Purpose |
|-----------|---------|
| `pg_cron` | Job scheduling |
| `wal2json` | Logical replication (Realtime) |
| `postgis` | Geospatial data |
| `http` | HTTP client functions |
| `timescaledb` | Time-series data |
| `pgaudit` | Audit logging |

All extensions are sourced from [Pigsty](https://pigsty.io/) repository for newer versions than standard PostgreSQL repos.

## Database Roles

Standard Supabase roles are created automatically (defined in [official Supabase repos](https://github.com/supabase/postgres)):

### Administrative Roles
- `supabase_admin` - Superuser with full privileges
- `service_role` - Backend service access with RLS bypass
- Service admin roles for auth, storage, and functions

### API Roles
- `authenticator` - Connection pooler role
- `anon` - Unauthenticated API access
- `authenticated` - Authenticated user API access

### Operational Roles
- `supabase_replication_admin` - Replication management
- `supabase_read_only_user` - Read-only access with RLS bypass

The Zalando Postgres Operator creates these roles and stores credentials in Kubernetes secrets.

## High Availability

Deployment is managed by the [Zalando Postgres Operator](https://github.com/zalando/postgres-operator) using [Spilo](https://github.com/zalando/spilo) (PostgreSQL + Patroni).

### Key Features

- **Automatic failover** - Patroni detects failures and promotes replicas
- **Streaming replication** - PostgreSQL native replication
- **Connection pooling** - PGBouncer for efficient connection management
- **Backup/restore** - WAL-G continuous archiving to S3/MinIO
- **Point-in-time recovery** - Restore to any moment in time

### Deployment Options

| Configuration | Nodes | HA | Use Case |
|---------------|-------|-----|----------|
| Single | 1 | No | Development, testing |
| Duo | 2 | Yes | Staging, small production |
| Trio | 3 | Yes | Production |

## How It Works

1. **Image Creation**: Supabase extensions and migrations are baked into a custom Spilo Docker image
2. **Bootstrap**: On first start, Patroni calls a bootstrap script that runs all Supabase migrations
3. **Ready**: Database starts with complete Supabase schema, extensions, and roles
4. **HA**: Patroni manages replication and failover automatically

Migrations are sourced directly from the official Supabase repositories and run once during cluster initialization.

## Connection Endpoints

When deployed, the operator creates these services:

- **`<cluster>-pooler`** - Connection pooler (recommended for apps)
- **`<cluster>`** - Direct primary connection
- **`<cluster>-repl`** - Read replicas

## Differences from Managed Supabase

### What's Included ✅
- Complete Supabase database (all schemas, extensions, roles)
- Production-ready PostgreSQL HA
- Automatic backups and PITR
- Connection pooling
- Full control over infrastructure

### What's Not Included ❌
- Supabase services (you deploy separately):
  - GoTrue (Auth)
  - PostgREST (API)
  - Storage
  - Realtime
  - Edge Functions runtime
- Supabase Dashboard/Studio
- Hosted management

This is a **database-only** solution. You deploy the Supabase services separately and point them to this database.

## For More Details

- Zalando Postgres Operator: https://postgres-operator.readthedocs.io/
- Spilo Architecture: https://github.com/zalando/spilo
- Patroni HA: https://github.com/zalando/patroni
- Supabase Database Schema: https://github.com/supabase/postgres
