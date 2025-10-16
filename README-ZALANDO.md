# Supabase on Zalando Postgres Operator

Production-ready PostgreSQL cluster for Supabase with HA, automatic failover, and complete Supabase schema initialization.

## Why Zalando Instead of CloudNativePG?

**CloudNativePG limitation discovered:**
- Custom bootstrap ignores `/docker-entrypoint-initdb.d/` scripts
- Only `postInitSQL` in manifest runs (one-shot, SQL-only, revokes privileges)
- Cannot create SUPERUSER/BYPASSRLS roles after bootstrap

**Zalando solution:**
- Patroni bootstrap **calls scripts from the image** (`post_init.sh`)
- Scripts at `/scripts/` execute automatically during initialization
- Full SUPERUSER access available anytime via declarative manifest
- **Your existing migrations work - just different execution mechanism**

## Quick Start

### 1. Build Custom Spilo Image

```bash
# Update registry in command
docker build -f Dockerfile.spilo -t ghcr.io/your-org/spilo-supabase:17-1.0.0 .
docker push ghcr.io/your-org/spilo-supabase:17-1.0.0
```

### 2. Install Zalando Operator

```bash
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm install postgres-operator postgres-operator-charts/postgres-operator --namespace postgres-operator --create-namespace
```

### 3. Create Backup Credentials

```bash
kubectl create secret generic backup-s3-credentials \
  --from-literal=access-key-id=YOUR_KEY \
  --from-literal=secret-access-key=YOUR_SECRET \
  --namespace supabase
```

### 4. Deploy Database

```bash
# Edit manifests/supabase-postgres-zalando.yaml first:
# - Update dockerImage to your registry
# - Update storageClass
# - Update backup S3 configuration

kubectl apply -f manifests/supabase-postgres-zalando.yaml
```

### 5. Get Credentials

```bash
# Retrieve authenticator password for Supabase
kubectl get secret authenticator.supabase-db.credentials.postgresql.acid.zalan.do \
  -n supabase -o jsonpath='{.data.password}' | base64 -d
```

### 6. Connect Supabase Services

```yaml
POSTGRES_HOST: supabase-db-pooler.supabase.svc.cluster.local
POSTGRES_PORT: 5432
POSTGRES_DB: postgres
POSTGRES_USER: authenticator
POSTGRES_PASSWORD: <from-secret>
```

## What Gets Created

### Supabase Schemas
- ✅ `auth` - User authentication
- ✅ `storage` - File storage
- ✅ `realtime` - WebSocket subscriptions
- ✅ `extensions` - PostgreSQL extensions
- ✅ `supabase_functions` - Edge Functions
- ✅ `graphql_public` - GraphQL API
- ✅ `_analytics` - Internal analytics
- ✅ `_realtime` - Internal realtime

### Supabase Extensions
- ✅ `pg_net` - Async HTTP (Edge Functions)
- ✅ `pgsodium` - Encryption
- ✅ `supabase_vault` - Secrets management
- ✅ `pg_graphql` - GraphQL API
- ✅ `supautils` - Supabase utilities
- ✅ `pgvector` - Vector similarity (AI/embeddings)
- ✅ `pg_tle` - Trusted Language Extensions
- ✅ `pg_cron` - Job scheduling
- ✅ `wal2json` - Realtime replication
- ✅ `postgis` - Geospatial data

### Supabase Roles
- ✅ `supabase_admin` (SUPERUSER, BYPASSRLS, CREATEDB, CREATEROLE, REPLICATION)
- ✅ `service_role` (BYPASSRLS)
- ✅ `authenticator` (LOGIN, grants to anon/authenticated)
- ✅ `supabase_auth_admin` (CREATEROLE)
- ✅ `supabase_storage_admin` (CREATEROLE)
- ✅ `supabase_functions_admin` (CREATEROLE)
- ✅ `supabase_replication_admin` (REPLICATION)
- ✅ `supabase_read_only_user` (BYPASSRLS)
- ✅ `anon` (NOLOGIN)
- ✅ `authenticated` (NOLOGIN)

### Infrastructure
- ✅ 3-node PostgreSQL cluster (1 primary + 2 replicas)
- ✅ Automatic failover via Patroni
- ✅ PGBouncer connection pooler (2 instances)
- ✅ WAL-G backups to S3/MinIO
- ✅ Point-in-time recovery (PITR)
- ✅ Prometheus metrics exporter

## Architecture

```
┌─────────────────────────────────────────────────────┐
│          Zalando Postgres Operator                  │
│  (Manages PostgreSQL clusters via Patroni)          │
└───────────────────┬─────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│               Custom Spilo Image                     │
│  - PostgreSQL 17                                     │
│  - Patroni (HA/failover)                             │
│  - Supabase extensions (via Pigsty)                  │
│  - Supabase migrations (baked in)                    │
│  - post_init.sh hook (runs migrations)               │
└───────────────────┬─────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
┌──────────────┐        ┌──────────────┐
│  Primary Pod │        │ Replica Pods │
│  (Read/Write)│        │  (Read-only) │
└──────────────┘        └──────────────┘
        │                       │
        └───────────┬───────────┘
                    ▼
        ┌──────────────────────┐
        │  PGBouncer Pooler    │
        │  (Connection pooling)│
        └──────────────────────┘
                    │
                    ▼
        ┌──────────────────────┐
        │  Supabase Services   │
        │  (Auth, Storage, etc)│
        └──────────────────────┘
```

## File Structure

```
.
├── Dockerfile.spilo                    # Custom Spilo image (extends Zalando base)
├── scripts/
│   └── supabase_post_init.sh          # Migration runner (called by Patroni)
├── migrations/
│   ├── custom-init-scripts/           # Custom setup (pgbouncer, functions)
│   ├── init-scripts/                  # Core schemas (auth, storage, realtime)
│   └── migrations/                    # Incremental updates (timestamped)
├── manifests/
│   └── supabase-postgres-zalando.yaml # Kubernetes manifest for database
└── docs/
    ├── Migration to Zalando Postgres Operator - Analysis and Proposal.md
    └── Build and Deploy Guide - Zalando.md
```

## Key Differences from CloudNativePG

| Feature | CloudNativePG | Zalando |
|---------|---------------|---------|
| **Image scripts** | Ignored (custom bootstrap) | Executed (Patroni calls them) |
| **SUPERUSER roles** | Bootstrap only, then revoked | Anytime via manifest |
| **BYPASSRLS roles** | Bootstrap only | Anytime via manifest |
| **Role updates** | Requires cluster rebuild | Update manifest, auto-synced |
| **Init hooks** | `postInitSQL` (SQL, once) | `post_init.sh` (script, repeatable) |
| **Migration approach** | Manifest SQL only | Image scripts + manifest |

## Verification Commands

```bash
# Check cluster status
kubectl get postgresql -n supabase

# Check pods
kubectl get pods -n supabase -l cluster-name=supabase-db

# View migration logs
kubectl logs supabase-db-0 -n supabase | grep -A 20 "Supabase"

# Connect to database
kubectl exec -it supabase-db-0 -n supabase -- psql -U postgres

# Inside psql:
\dn          -- Check schemas
\dx          -- Check extensions
\du          -- Check roles
\dt auth.*   -- Check auth tables
```

## Documentation

- [Full Analysis and Proposal](docs/Migration%20to%20Zalando%20Postgres%20Operator%20-%20Analysis%20and%20Proposal.md)
- [Build and Deploy Guide](docs/Build%20and%20Deploy%20Guide%20-%20Zalando.md)
- [CloudNativePG vs Zalando Comparison](docs/CloudNativePG%20vs%20Zalando%20Postgres%20Operator%20for%20Supabase.md)

## Support

Issues: https://github.com/klosowsk/cnpg-supabase/issues

## License

Apache License 2.0

## Acknowledgments

- [Zalando Postgres Operator](https://github.com/zalando/postgres-operator)
- [Spilo](https://github.com/zalando/spilo)
- [Patroni](https://github.com/zalando/patroni)
- [Pigsty](https://pigsty.io/)
- [Supabase](https://supabase.com/)
