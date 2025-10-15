# cloudnativepg-supabase

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue.svg)](https://www.postgresql.org/)
[![CloudNativePG](https://img.shields.io/badge/CloudNativePG-Compatible-green.svg)](https://cloudnative-pg.io/)

PostgreSQL 15 with Supabase extensions and migrations pre-installed for CloudNativePG.

## Versioning

This image follows semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR** (15) = PostgreSQL major version (tracks latest 15.x from CloudNativePG)
- **MINOR** (0) = Feature updates (new migrations, extension updates)
- **PATCH** (0) = Bug fixes only

**Available tags:**
- `15.0.0` - Exact version, never changes (recommended for production)
- `15.0` - Latest patch for 15.0.x (gets bug fixes automatically)

**Example:** `v15.0.0` uses PostgreSQL 15.x (currently 15.14), `v16.0.0` would use PostgreSQL 16.x

**No `latest` or `15` tags** - always specify the version you want for predictable deployments.

**Why use this image?**
- ✅ **CloudNativePG native** - designed for Kubernetes operators with HA and automatic backups
- ✅ **Newer extensions** - uses [Pigsty](https://pigsty.io/) repository with latest stable versions
- ✅ **Complete Supabase schema** - auth, storage, GraphQL, and Edge Functions pre-configured
- ✅ **Zero-config migrations** - runs automatically on first boot

## Quick Start

### Kubernetes (CloudNativePG)

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: supabase-db
spec:
  instances: 3
  imageName: klosowsk/cloudnativepg-supabase:15.0.0

  storage:
    size: 20Gi

  postgresql:
    parameters:
      shared_preload_libraries: "pg_net,pg_cron"

  env:
    - name: POSTGRES_PASSWORD
      valueFrom:
        secretKeyRef:
          name: supabase-db-secret
          key: password
    - name: JWT_SECRET
      valueFrom:
        secretKeyRef:
          name: supabase-db-secret
          key: jwt-secret
```

### Docker

```bash
docker run -d \
  -e POSTGRES_PASSWORD=postgres \
  -e JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters \
  -p 5432:5432 \
  klosowsk/cloudnativepg-supabase:15.0.0
```

Migrations run automatically on first boot. Check logs: `docker logs -f <container>`

## Configuration

### Required Environment Variables

| Variable            | Required | Description                                     | Example                                                   |
| ------------------- | -------- | ----------------------------------------------- | --------------------------------------------------------- |
| `POSTGRES_PASSWORD` | ✅       | Master password for all database roles          | `your-secure-password`                                    |
| `JWT_SECRET`        | ✅       | JWT signing key (min 32 characters)             | `your-super-secret-jwt-token-with-at-least-32-characters` |
| `JWT_EXP`           | ⚠️       | JWT expiration in seconds (default: 3600)       | `3600`                                                    |

### Required PostgreSQL Parameters

Background worker extensions need preloading:

```yaml
postgresql:
  parameters:
    shared_preload_libraries: "pg_net,pg_cron"
```

**Why?** Extensions like `pg_net` (async HTTP) and `pg_cron` (job scheduling) start background processes that must load at server startup.

### Extensions Included

All critical Supabase extensions with newer versions from Pigsty:

| Extension         | Version | Purpose                             |
| ----------------- | ------- | ----------------------------------- |
| **pg_net**        | 0.14.0  | Async HTTP (Edge Functions)         |
| **pgsodium**      | 3.1.9   | Encryption (Vault)                  |
| **vault**         | 0.3.1   | Secrets management                  |
| **pg_graphql**    | 1.5.11  | GraphQL API                         |
| **supautils**     | 2.10.0  | Supabase utilities                  |
| **pgvector**      | 0.8.1   | Vector similarity (AI/embeddings)   |
| **pg_tle**        | 1.5.1   | Trusted Language Extensions         |
| **pg_cron**       | 1.6.7   | Job scheduling                      |
| **wal2json**      | 2.6     | Realtime replication                |
| **postgis**       | 3.6.0   | Geospatial data                     |

## How It Works

### What Gets Installed

**Migrations** set up the complete Supabase database schema:
- **Auth schema** - user authentication, sessions, JWT tokens
- **Storage schema** - file storage buckets and permissions
- **Realtime schema** - WebSocket subscriptions and filters
- **Edge Functions** - database webhooks via HTTP
- **Utility databases** - internal Supabase coordination

**Why migrations?** Supabase is more than just extensions - it's a complete platform. The migrations create the schemas, functions, and triggers that power Supabase's auth, storage, and realtime features.

### Migration Execution

Migrations run automatically on first boot (when data directory is empty):

1. PostgreSQL starts with `supabase_admin` as the initial superuser
2. Custom init scripts run first: monitoring setup, Edge Functions, utility databases
3. Supabase migrations run next: auth, storage, realtime schemas
4. Database is ready with full Supabase functionality

**CloudNativePG replicas are safe** - only the primary runs migrations, replicas clone via `pg_basebackup`.

## Building and Debugging

### Build Locally

```bash
git clone git@github.com:klosowsk/cloudnativepg-supabase.git
cd cloudnativepg-supabase
./build.sh
```

### Debug Migrations

```bash
# Start with verbose logging
docker run --name debug \
  -e POSTGRES_PASSWORD=test \
  -e JWT_SECRET=test-secret-with-at-least-32-characters-long \
  -d klosowsk/cloudnativepg-supabase:15

# Watch migration execution
docker logs -f debug

# Verify extensions installed
docker exec debug psql -U postgres -c "\dx"

# Check schemas created
docker exec debug psql -U postgres -c "\dn"

# Cleanup
docker rm -f debug
```

### Common Issues

**Migrations not running?**
- Check logs: `docker logs <container>`
- Verify data directory is empty on first boot
- Ensure `JWT_SECRET` is set (required for migrations)

**Extension not available?**
- Some extensions need `shared_preload_libraries` (see Configuration above)
- Verify extension installed: `docker exec <container> apt list --installed | grep postgresql-15`

**Permission errors?**
- Migrations create `supabase_admin` role automatically
- Check roles: `docker exec <container> psql -U postgres -c "\du"`

## Comparison with Official Supabase Image

| Feature              | Official Supabase | This Image  |
| -------------------- | ----------------- | ----------- |
| **Base**             | Debian custom     | CloudNativePG |
| **HA/Replicas**      | Manual setup      | ✅ Built-in |
| **Backups**          | External tools    | ✅ Integrated |
| **pg_net**           | 0.7.1             | ✅ 0.14.0 |
| **pgvector**         | 0.4.0             | ✅ 0.8.1 |
| **supautils**        | 2.2.0             | ✅ 2.10.0 |
| **Kubernetes-native**| ❌                | ✅ Yes |

## License

Apache License 2.0 - see [LICENSE](LICENSE)

## Acknowledgments

Built with [CloudNativePG](https://cloudnative-pg.io/), [Supabase](https://supabase.com/), and [Pigsty](https://pigsty.io/)
