# Supabase HA Deployment Examples

This directory contains reference configurations for deploying Supabase with High Availability PostgreSQL.

## Directory Structure

```
examples/
├── postgres-operator/      # Tier 1: Zalando Postgres Operator (install once)
├── development/            # Tier 2: Dev environment (reference, ephemeral)
├── high-availability/      # Tier 2: Production-ready HA setup (reference)
├── storage/                # Storage configuration examples
└── README.md               # This file
```


## Prerequisites

Before deploying Supabase, ensure you have:

- **Kubernetes cluster** (1.21+)
- **kubectl** configured and connected
- **Helm 3.8+** installed
- **Ingress controller** (optional, for external access)

### Storage Prerequisites (IMPORTANT)

**The Helm chart does NOT create StorageClasses or PersistentVolumes.** You must configure storage infrastructure before deploying Supabase.

#### For Development/Testing
The development example uses **K3s local-path** (ephemeral):
```yaml
postgresql:
  volume:
    size: 2Gi
    storageClass: local-path  # example - data persists on node disk
```

#### For Production/High-Availability
Choose one of these storage strategies:

**Option 1: Dynamic Provisioning** (Recommended)
- Cloud providers (AWS EBS, Azure Disk, GCP PD)
- Longhorn, Rook-Ceph, or similar
- Volumes are auto-created when PostgreSQL starts
- See: [storage/README.md](./storage/README.md) for examples

**Option 2: Local Static Provisioning** (K3s/Homelab)
- Manually create PersistentVolumes on local disks
- Best for homelab clusters with local SSD/NVMe
- Requires one PV per PostgreSQL instance
- See: [storage/local-static/](./storage/local-static/) for setup

See [storage/README.md](./storage/README.md) for complete storage setup guide.

## Architecture Overview

```
┌────────────────────────────────────────────────────┐
│  Tier 1: PostgreSQL Operator (Cluster-Scoped)      │
│  ┌──────────────────────────────────────────────┐  │
│  │  Zalando Postgres Operator                   │  │
│  │  • Installed once per cluster                │  │
│  │  • Watches all namespaces (or specific)      │  │
│  │  • Creates PostgreSQL clusters via CRDs      │  │
│  └──────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────┘
         │ manages multiple Supabase instances
         ├──────────────┬──────────────┬──────────────┐
         ▼              ▼              ▼              ▼
    ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
    │   Dev   │   │   HA    │   │   HA    │   │ Tenant  │
    │namespace│   │  Prod   │   │ Staging │   │namespace│
    └─────────┘   └─────────┘   └─────────┘   └─────────┘
```

## Quick Start

### Step 1: Install PostgreSQL Operator (Once)

Using the provided Helm installation script:

```bash
cd postgres-operator/
./helm-install.sh
```

Or manually:

```bash
helm repo add postgres-operator-charts \
  https://opensource.zalando.com/postgres-operator/charts/postgres-operator

helm install postgres-operator \
  postgres-operator-charts/postgres-operator \
  --namespace postgres-operator \
  --create-namespace \
  --values postgres-operator/values.yaml
```

#### Verify Operator Installation

```bash
# Check operator is running
kubectl get pods -n postgres-operator

# Check CRD is registered
kubectl get crd postgresqls.acid.zalan.do

# View operator logs
kubectl logs -n postgres-operator -l app.kubernetes.io/name=postgres-operator
```

### Step 2: Deploy Supabase Environment

#### Development Environment

Minimal resources, single instance, ephemeral storage, includes development JWT secrets:

```bash
# Install with development defaults (includes demo JWT secrets)
helm install supabase-dev ../helm-charts/supabase-ha \
  --namespace dev-supabase \
  --create-namespace \
  --values development/values.yaml

# Wait for PostgreSQL cluster
kubectl wait --for=condition=ready pod \
  -l cluster-name=dev-supabase-db \
  -n dev-supabase \
  --timeout=300s

# Port-forward to access
kubectl port-forward -n dev-supabase svc/supabase-dev-kong 8000:8000 &
kubectl port-forward -n dev-supabase svc/supabase-dev-studio 3000:3000 &

# Access:
# API: http://localhost:8000
# Studio: http://localhost:3000 (user: supabase, pass: supabase)
```

#### High Availability Environment (Reference)

Full HA with 3 PostgreSQL replicas, multiple service replicas:

```bash
# IMPORTANT: Copy and customize high-availability/values.yaml
# Configure:
# - JWT secrets (REQUIRED - see Secret Generation below)
# - Dashboard password (REQUIRED)
# - StorageClass name for your cluster
# - Domain names
# - SMTP settings (for production email)
# - Resource limits (adjust for your workload)

# Install
helm install supabase-ha ../helm-charts/supabase-ha \
  --namespace ha-supabase \
  --create-namespace \
  --values high-availability/values.yaml

# Wait for cluster
kubectl wait --for=condition=ready pod \
  -l cluster-name=ha-supabase-db \
  -n ha-supabase \
  --timeout=300s
```

## Secret Generation

### JWT Secrets

Generate using Supabase CLI or manually:

```bash
# Method 1: Use Supabase JWT generator
# https://supabase.com/docs/guides/self-hosting#api-keys

# Method 2: Manual generation
# Generate a 256-bit secret
JWT_SECRET=$(openssl rand -base64 32)
echo "JWT Secret: $JWT_SECRET"

# Generate anon key (expires in 10 years)
# Use https://jwt.io with:
# {
#   "role": "anon",
#   "iss": "supabase",
#   "iat": $(date +%s),
#   "exp": $(date -d "+10 years" +%s)
# }

# Generate service_role key
# {
#   "role": "service_role",
#   "iss": "supabase",
#   "iat": $(date +%s),
#   "exp": $(date -d "+10 years" +%s)
# }
```

### Analytics API Key

```bash
# Generate random base64 string
openssl rand -base64 32
```

### Dashboard Password

```bash
# Generate strong password
openssl rand -base64 24
```

## Accessing Your Deployment

### Port-Forward (Development)

```bash
# Kong API Gateway (main API endpoint)
kubectl port-forward -n <namespace> svc/<release-name>-kong 8000:8000

# Studio Dashboard (admin UI)
kubectl port-forward -n <namespace> svc/<release-name>-studio 3000:3000

# Direct PostgreSQL (for debugging)
kubectl port-forward -n <namespace> svc/<cluster-name>-rw 5432:5432
```

### Ingress (Production)

Configure in your values file:

```yaml
kong:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: api.yourdomain.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: api-tls
        hosts:
          - api.yourdomain.com

studio:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: studio.yourdomain.com
        paths:
          - path: /
            pathType: Prefix
```

## Retrieving Auto-Generated Database Credentials

The Zalando operator auto-generates passwords for all database users. Retrieve them:

```bash
# List all generated secrets
kubectl get secrets -n <namespace> | grep postgresql.acid.zalan.do

# Get password for supabase_admin user
kubectl get secret supabase-admin.<cluster-name>.credentials.postgresql.acid.zalan.do \
  -n <namespace> \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Get password for postgres superuser
kubectl get secret postgres.<cluster-name>.credentials.postgresql.acid.zalan.do \
  -n <namespace> \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

Secret naming pattern:
```
{username}.{cluster-name}.credentials.postgresql.acid.zalan.do
```

## Monitoring Your Deployment

### PostgreSQL Cluster Status

```bash
# Check PostgreSQL pods
kubectl get pods -n <namespace> -l cluster-name=<cluster-name>

# Check PostgreSQL cluster CR
kubectl get postgresql -n <namespace>

# Describe cluster for details
kubectl describe postgresql <cluster-name> -n <namespace>

# Check PgBouncer pooler pods
kubectl get pods -n <namespace> -l connection-pooler=<cluster-name>-pooler
```

### Supabase Services Status

```bash
# All pods
kubectl get pods -n <namespace>

# Specific service
kubectl get pods -n <namespace> -l app.kubernetes.io/component=auth

# Service logs
kubectl logs -n <namespace> -l app.kubernetes.io/component=auth --tail=100 -f
```

### PostgreSQL Metrics

The high-availability example includes an optional prometheus-postgres-exporter sidecar (commented out by default):

```bash
# Port-forward metrics endpoint (if enabled)
kubectl port-forward -n <namespace> \
  -l cluster-name=<cluster-name> \
  9187:9187

# Scrape metrics
curl http://localhost:9187/metrics
```

## Upgrading

### Upgrade Postgres Operator

```bash
helm repo update postgres-operator-charts

helm upgrade postgres-operator \
  postgres-operator-charts/postgres-operator \
  --namespace postgres-operator \
  --values postgres-operator/values.yaml
```

### Upgrade Supabase

```bash
# Pull latest chart
cd ../helm-charts/
git pull

# Upgrade deployment
helm upgrade <release-name> ./supabase-ha \
  --namespace <namespace> \
  --values examples/<environment>/values.yaml
```

## Backup and Restore

### PostgreSQL Backups

Configure WAL archiving and point-in-time recovery (PITR) by adding to `postgresql.env` in values:

```yaml
postgresql:
  env:
    - name: WAL_S3_BUCKET
      value: "your-backup-bucket"
    - name: AWS_ENDPOINT
      value: "https://s3.amazonaws.com"
    - name: AWS_REGION
      value: "us-east-1"
    - name: AWS_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          name: backup-s3-credentials
          key: access-key-id
    - name: AWS_SECRET_ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: backup-s3-credentials
          key: secret-access-key
    - name: BACKUP_SCHEDULE
      value: "0 2 * * *"  # Daily at 2 AM
```

See [Spilo backup documentation](https://github.com/zalando/spilo#wal-e) for details.

### Manual Backup

```bash
# Get database password
DB_PASS=$(kubectl get secret supabase-admin.<cluster-name>.credentials.postgresql.acid.zalan.do \
  -n <namespace> -o jsonpath='{.data.password}' | base64 -d)

# Port-forward PostgreSQL
kubectl port-forward -n <namespace> svc/<cluster-name>-rw 5432:5432 &

# Backup
PGPASSWORD=$DB_PASS pg_dump \
  -h localhost -p 5432 \
  -U supabase_admin \
  -d postgres \
  -F custom \
  -f backup-$(date +%Y%m%d-%H%M%S).dump
```

## Troubleshooting

### PostgreSQL Cluster Won't Start

```bash
# Check operator logs
kubectl logs -n postgres-operator -l app.kubernetes.io/name=postgres-operator --tail=100

# Check PostgreSQL CR events
kubectl describe postgresql <cluster-name> -n <namespace>

# Check pod events
kubectl describe pod -n <namespace> -l cluster-name=<cluster-name>

# Check PVC status
kubectl get pvc -n <namespace>
```

### Services Can't Connect to Database

```bash
# Verify secrets exist
kubectl get secrets -n <namespace> | grep postgresql.acid.zalan.do

# If secrets missing, wait - operator creates them asynchronously (30-60s)
kubectl wait --for=condition=ready pod \
  -l cluster-name=<cluster-name> \
  -n <namespace> \
  --timeout=300s

# Then check secrets again
kubectl get secrets -n <namespace> | grep postgresql.acid.zalan.do
```

### Init Container Stuck Waiting for Database

```bash
# Check PostgreSQL is actually ready
kubectl get postgresql -n <namespace>

# Check database pod logs
kubectl logs -n <namespace> -l cluster-name=<cluster-name> -c postgres

# Test connection manually
kubectl run psql-test --rm -it --image=postgres:15-alpine -n <namespace> -- \
  psql -h <cluster-name>-rw -U supabase_admin -d postgres
```

### Ingress Not Working

```bash
# Check ingress exists
kubectl get ingress -n <namespace>

# Describe ingress for details
kubectl describe ingress <ingress-name> -n <namespace>

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

## Environment Comparison (defaults)

| Feature | Development | High Availability |
|---------|-------------|-------------------|
| PostgreSQL Instances | 1 | 3 (adjustable) |
| Synchronous Replication | No | Yes |
| Service Replicas | 1 | 2-3 |
| Memory (PostgreSQL) | 2Gi | 8Gi |
| Storage Size | 2Gi | 100Gi |
| StorageClass | local-path (K3s) | Customize for your cluster |
| PgBouncer Pooler | 1 | 3 |
| Email Auto-confirm | Yes | No |
| SMTP Required | No | Yes |
| Ingress/TLS | Optional | Commented examples |
| JWT Secrets | Demo (included) | Must generate |
| Monitoring | Basic | Optional Prometheus sidecar |
| Backups | None | Optional S3/WAL archiving |

## Additional Resources

- [Zalando Postgres Operator Documentation](https://postgres-operator.readthedocs.io/)
- [Supabase Self-Hosting Guide](https://supabase.com/docs/guides/self-hosting)
- [Spilo (PostgreSQL + Patroni)](https://github.com/zalando/spilo)
- [Main Project README](../README.md)

## Support

For issues or questions:
- Check [Troubleshooting](#troubleshooting) section
- Review [Zalando Operator Logs](#postgresql-cluster-wont-start)
- Open an issue on GitHub
