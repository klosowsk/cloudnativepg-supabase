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

**No `latest` or `15` tags** - always specify the version you want for predictable deployments.

**Why use this image?**
- ✅ **CloudNativePG native** - designed for Kubernetes operators with HA and automatic backups
- ✅ **Newer extensions** - uses [Pigsty](https://pigsty.io/) repository with latest stable versions
- ✅ **Complete Supabase schema** - auth, storage, GraphQL, and Edge Functions pre-configured
- ✅ **Kubernetes-native initialization** - migrations run via ConfigMaps, not Docker entrypoints

**⚠️ Important:** This image is designed exclusively for CloudNativePG in Kubernetes. It does NOT work as a standalone Docker container like the official PostgreSQL images.

## Quick Start

### Prerequisites

1. **CloudNativePG operator** installed in your Kubernetes cluster
2. **kubectl** configured to access your cluster

### Installation

**1. Generate SQL files:**

```bash
git clone https://github.com/klosowsk/cloudnativepg-supabase.git
cd cloudnativepg-supabase
./scripts/generate-configmaps.sh
```

**2. Configure secrets:**

Edit `k8s/overlays/dev/kustomization.yaml`:

```yaml
secretGenerator:
- name: supabase-db-secret
  literals:
  - password=YOUR-PASSWORD
  - jwt-secret=YOUR-JWT-SECRET-MIN-32-CHARS
```

**3. Deploy:**

```bash
kubectl apply -k k8s/overlays/dev/
```

**4. Monitor:**

```bash
kubectl logs -f supabase-db-1 -n supabase-dev -c postgres
```

### ArgoCD Deployment

Point your ArgoCD Application to:
- **Path:** `k8s/overlays/dev`
- **Namespace:** `supabase-dev`

ArgoCD will automatically generate ConfigMaps from SQL files and deploy.

See [k8s/README.md](k8s/README.md) for details.

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

Migrations run automatically via CloudNativePG's `postInitApplicationSQLRefs` when the cluster is first created:

1. **ConfigMaps deployed** - Migration SQL scripts packaged as Kubernetes ConfigMaps
2. **Cluster bootstrap** - CloudNativePG creates the cluster and references the ConfigMaps
3. **Initialization phase** - PostgreSQL runs the master SQL script as superuser:
   - Phase 1: Custom init scripts (pgbouncer, monitoring, utility databases)
   - Phase 2: Supabase init scripts (initial schema, roles, extensions)
   - Phase 3: Supabase migrations (auth, storage, realtime schemas)
4. **Database ready** - Full Supabase functionality available

**CloudNativePG replicas are safe** - only the primary runs initialization, replicas clone via `pg_basebackup`.

**Important:** CloudNativePG images do NOT use `/docker-entrypoint-initdb.d/`. Initialization must be configured via the Cluster manifest's `bootstrap.initdb.postInitApplicationSQLRefs` section.

## Building and Debugging

### Build Locally

```bash
git clone git@github.com:klosowsk/cloudnativepg-supabase.git
cd cloudnativepg-supabase

# Prepare migrations (pulls latest from supabase/postgres)
./scripts/prepare-init-scripts.sh

# Generate ConfigMaps
./scripts/generate-configmaps.sh

# Build image
./build.sh
```

### Troubleshooting

**Cluster stuck in bootstrapping?**

```bash
# Check cluster status
kubectl get cluster supabase-db -o yaml

# Check pod logs for initialization errors
kubectl logs supabase-db-1 -c postgres

# Common issues:
# - JWT_SECRET not set in Secret
# - ConfigMap not created or wrong name
# - Syntax error in SQL migrations
```

**Migrations not running?**

```bash
# Verify ConfigMap exists
kubectl get configmap supabase-master-init

# Check if Secret exists
kubectl get secret supabase-db-secret

# Verify Cluster references the ConfigMap
kubectl get cluster supabase-db -o jsonpath='{.spec.bootstrap.initdb.postInitApplicationSQLRefs}'

# Check initialization logs
kubectl logs supabase-db-1 -c postgres | grep -A 50 "Supabase Initialization"
```

**Extension not available?**

```bash
# Connect to the database
kubectl exec -it supabase-db-1 -- psql -U postgres

# List installed extensions
\dx

# Try creating the extension
CREATE EXTENSION IF NOT EXISTS pg_net;

# If it fails, check if the package is installed
kubectl exec -it supabase-db-1 -- apt list --installed | grep postgresql-15
```

**Permission errors?**

```bash
# List database roles
kubectl exec -it supabase-db-1 -- psql -U postgres -c "\du"

# Verify supabase_admin exists and is superuser
kubectl exec -it supabase-db-1 -- psql -U postgres -c "SELECT rolname, rolsuper FROM pg_roles WHERE rolname = 'supabase_admin';"
```

**Need to re-run migrations?**

CloudNativePG runs `postInitApplicationSQLRefs` only during initial bootstrap. To re-run migrations:

```bash
# Option 1: Delete and recreate the cluster (loses all data!)
kubectl delete cluster supabase-db
kubectl apply -f examples/cluster.yaml

# Option 2: Manually run migrations
kubectl exec -it supabase-db-1 -- psql -U postgres < <(kubectl get configmap supabase-master-init -o jsonpath='{.data.master-init\.sql}')
```

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
