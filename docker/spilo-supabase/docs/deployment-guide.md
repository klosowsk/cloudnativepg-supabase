# Deployment Guide

## Quick Start

Deploy Supabase-ready PostgreSQL with HA using Zalando Postgres Operator.

### 1. Install Zalando Postgres Operator

```bash
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm install postgres-operator postgres-operator-charts/postgres-operator \
  --namespace postgres-operator --create-namespace
```

Verify:
```bash
kubectl get pods -n postgres-operator
```

### 2. Create Backup Credentials (Optional)

For production with backups:

```bash
kubectl create namespace supabase
kubectl create secret generic backup-s3-credentials \
  --from-literal=access-key-id=YOUR_KEY \
  --from-literal=secret-access-key=YOUR_SECRET \
  -n supabase
```

### 3. Deploy Database

Choose a template and customize for your environment:

```bash
# Download a template
curl -O https://raw.githubusercontent.com/klosowsk/spilo-supabase/main/manifests/supabase-postgres-zalando-trio.yaml

# Edit the manifest (see customization points marked with TODO)
vi supabase-postgres-zalando-trio.yaml

# Deploy
kubectl apply -f supabase-postgres-zalando-trio.yaml
```

### 4. Watch Deployment

```bash
kubectl get postgresql -n supabase -w
```

Wait for `Running` status.

### 5. Get Credentials

```bash
# Retrieve authenticator password
kubectl get secret authenticator.supabase-db.credentials.postgresql.acid.zalan.do \
  -n supabase -o jsonpath='{.data.password}' | base64 -d
```

### 6. Connect Supabase Services

Configure your Supabase services:

```yaml
POSTGRES_HOST: supabase-db-pooler.supabase.svc.cluster.local
POSTGRES_PORT: 5432
POSTGRES_DB: postgres
POSTGRES_USER: authenticator
POSTGRES_PASSWORD: <from-secret>
```

## How It Works: Role Creation Lifecycle

Understanding the bootstrap process helps troubleshoot deployment issues.

### Bootstrap Sequence

1. **Patroni Initialization** - Zalando operator starts Patroni, which initializes PostgreSQL
2. **Supabase Pre-Creation** (`/supabase-migrations/custom-init-scripts/00-create-supabase-roles.sql`)
   - Creates all Supabase roles with placeholder passwords
   - Runs during `post_init` BEFORE operator reconciliation
   - Allows migrations to reference roles without errors
3. **Supabase Schema Migrations** - Auth, storage, realtime schemas created
4. **Bootstrap Completes** - PostgreSQL is running
5. **Operator Reconciliation** - Zalando operator processes manifest `users:` section
   - Detects roles already exist from step 2
   - Updates role attributes (SUPERUSER, CREATEDB, etc.)
   - Generates secure passwords
   - Stores credentials in Kubernetes secrets: `{rolename}.supabase-db.credentials.postgresql.acid.zalan.do`

### Why This Design?

**Problem**: Operator creates users AFTER bootstrap, but migrations need them DURING bootstrap.

**Solution**: Pre-create roles early, let operator manage them later.

- **Manifest `users:` section** - Source of truth for role management (KEEP THIS)
- **Pre-creation script** - Bootstrap helper to prevent migration errors
- **Operator reconciliation** - Securely manages passwords and attributes throughout cluster lifecycle

### What Gets Created

✅ **Schemas** (created by migrations):
- `auth`, `storage`, `vault`, `supabase_functions`
- `realtime`, `graphql`, `graphql_public`
- `extensions`, `pgbouncer`

⚠️ **Not created** (require external Supabase services):
- `_analytics` - Requires Supabase Analytics/Logflare service
- `_realtime` - Requires Supabase Realtime server

## Verification

```bash
# Check cluster
kubectl get postgresql -n supabase

# View logs
kubectl logs supabase-db-0 -n supabase | grep "Supabase"

# Connect and verify
kubectl exec -it supabase-db-0 -n supabase -- psql -U postgres
\dn          -- List schemas (should see auth, storage, realtime, etc.)
\dx          -- List extensions
\du          -- List roles (should see all Supabase roles)
```

## Template Customization

When editing the manifest, update these sections marked with `# TODO`:

### Required Changes
- `storageClass` - Your Kubernetes storage class
- `WAL_S3_BUCKET` - Your S3 bucket name (if using backups)
- `AWS_ENDPOINT` - Your S3/MinIO endpoint
- `AWS_REGION` - Your region

### Optional Changes
- `dockerImage` - If using custom registry
- `resources` - CPU/memory based on workload
- `volume.size` - Storage size for your data
- `numberOfInstances` - Number of replicas (1, 2, or 3)

## Operations

### Scale Replicas

Edit manifest and change `numberOfInstances`:
```yaml
numberOfInstances: 5  # Add more replicas
```

Apply:
```bash
kubectl apply -f supabase-postgres-zalando-trio.yaml
```

### Expand Storage

Edit manifest and increase `volume.size`:
```yaml
volume:
  size: 100Gi  # Increase size
```

Apply (requires storage class that supports expansion):
```bash
kubectl apply -f supabase-postgres-zalando-trio.yaml
```

### Backup and Restore

The operator handles automated backups to S3 via WAL-G.

**Manual backup:**
```bash
kubectl exec supabase-db-0 -n supabase -- \
  envdir /run/etc/wal-e.d/env wal-g backup-push /home/postgres/pgdata/pgroot/data
```

**Restore from backup:**

Create a new cluster manifest with:
```yaml
clone:
  cluster: supabase-db
  # For latest backup (omit timestamp)
  # For point-in-time: uncomment and set timestamp
  # timestamp: "2025-10-16T10:00:00Z"
```

### Update PostgreSQL Parameters

Edit manifest:
```yaml
postgresql:
  parameters:
    max_connections: "200"
    shared_buffers: "1GB"
```

Apply - operator restarts PostgreSQL with new config:
```bash
kubectl apply -f supabase-postgres-zalando-trio.yaml
```

## Troubleshooting

### Pods Not Starting

Check operator logs:
```bash
kubectl logs -n postgres-operator deployment/postgres-operator
```

Check pod events:
```bash
kubectl describe pod supabase-db-0 -n supabase
```

### Migrations Not Running

View pod logs:
```bash
kubectl logs supabase-db-0 -n supabase | grep -i supabase
```

Check if script exists:
```bash
kubectl exec supabase-db-0 -n supabase -- ls -la /scripts/supabase_post_init.sh
```

### Extensions Not Loading

Verify `shared_preload_libraries` in manifest includes:
```yaml
shared_preload_libraries: "timescaledb,pgsodium,pg_cron,pg_net,pg_stat_statements,auto_explain,pg_wait_sampling,pg_tle,plan_filter"
```

Check PostgreSQL config:
```bash
kubectl exec supabase-db-0 -n supabase -- psql -U postgres -c "SHOW shared_preload_libraries;"
```

### Connection Issues

Test from within cluster:
```bash
kubectl run -it --rm test-postgres --image=postgres:17 --restart=Never -- \
  psql -h supabase-db-pooler.supabase.svc.cluster.local -U authenticator -d postgres
```

## For More Details

This guide covers basic deployment with Zalando Postgres Operator. For advanced topics:

- **HA Configuration**: https://postgres-operator.readthedocs.io/en/latest/reference/patroni/
- **Backup/Restore**: https://postgres-operator.readthedocs.io/en/latest/user/#backup-and-restore
- **Monitoring**: https://postgres-operator.readthedocs.io/en/latest/user/#monitoring
- **Scaling**: https://postgres-operator.readthedocs.io/en/latest/user/#scaling
- **Security**: https://postgres-operator.readthedocs.io/en/latest/user/#security

Also see:
- [Architecture Overview](architecture.md) - What's included
- Zalando Operator Docs: https://postgres-operator.readthedocs.io/
