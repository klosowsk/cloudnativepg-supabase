# Installation Guide

Complete guide to deploying Supabase HA on Kubernetes.

## Prerequisites

### Cluster Requirements

- **Kubernetes**: 1.21 or later
- **Helm**: 3.8 or later
- **kubectl**: Configured and connected to your cluster
- **Storage**: Persistent volume support (local or cloud)

### Resource Requirements

#### Development

- 1 node with 2 CPU, 4Gi RAM minimum
- 10Gi storage

#### High Availability

- 3 nodes with 4 CPU, 8Gi RAM each minimum
- 300Gi storage (100Gi per PostgreSQL instance)

## Installation Steps

### Step 1: Install Zalando Postgres Operator

The operator must be installed once per cluster before deploying any Supabase instances.

```bash
# Add Helm repository
helm repo add postgres-operator-charts \
  https://opensource.zalando.com/postgres-operator/charts/postgres-operator

# Update repositories
helm repo update

# Install operator
helm install postgres-operator \
  postgres-operator-charts/postgres-operator \
  --namespace postgres-operator \
  --create-namespace
```

#### Verify Operator Installation

```bash
# Check operator pod is running
kubectl get pods -n postgres-operator

# Expected output:
# NAME                                 READY   STATUS    RESTARTS   AGE
# postgres-operator-xxxxxxxxxx-xxxxx   1/1     Running   0          30s

# Verify CRD is registered
kubectl get crd postgresqls.acid.zalan.do
```

For detailed operator configuration, see [examples/postgres-operator/README.md](../examples/postgres-operator/README.md).

### Step 2: Configure Storage

**Important**: The Helm chart does not create storage infrastructure. You must configure storage before deployment.

Choose your storage strategy:

#### Option A: Cloud Provider (AWS, Azure, GCP)

Use default storage classes provided by your cloud provider. No additional setup needed.

#### Option B: Dynamic Provisioning (Longhorn, Rook-Ceph, etc.)

Deploy a storage system that provides dynamic provisioning. See [examples/storage/README.md](../examples/storage/README.md) for examples.

#### Option C: Local Storage (K3s/Homelab)

Create PersistentVolumes manually. See [examples/storage/README.md](../examples/storage/README.md) for complete guide.

### Step 3: Generate Secrets

#### JWT Secret

Generate a secure JWT secret (minimum 32 characters):

```bash
# Generate random secret
openssl rand -base64 32
```

#### Generate JWT Keys

Use the Supabase JWT generator:

1. Visit: https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys
2. Generate `anon` and `service_role` keys with your JWT secret
3. Save for configuration in next step

#### Dashboard Password

```bash
# Generate secure password
openssl rand -base64 24
```

### Step 4: Create Values File

Create a `values.yaml` file with your configuration:

```yaml
global:
  clusterName: "my-supabase-db"

secret:
  jwt:
    anonKey: "your-generated-anon-key"
    serviceKey: "your-generated-service-role-key"
    secret: "your-jwt-secret-from-step-3"

  dashboard:
    username: "supabase"
    password: "your-dashboard-password"

postgresql:
  # Use custom Spilo Supabase image
  dockerImage: klosowsk/spilo-supabase:15.8.1.085-3.2-p1

  # For development: 1 instance
  # For HA: 3 instances
  numberOfInstances: 1

  # Adjust for your storage class
  volume:
    size: 10Gi
    storageClass: "longhorn"  # or your storage class name

# Optional: Configure ingress
kong:
  ingress:
    enabled: false  # Set true for external access
```

Or use reference examples as a starting point:

```bash
# Copy and customize for your needs
cp examples/development/values.yaml my-values.yaml
# or
cp examples/high-availability/values.yaml my-values.yaml
```

### Step 5: Deploy Supabase

```bash
helm install supabase ./helm-charts/supabase-ha \
  --namespace supabase \
  --create-namespace \
  --values my-values.yaml
```

### Step 6: Wait for Deployment

```bash
# Watch PostgreSQL cluster creation
kubectl get postgresql -n supabase -w

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=supabase \
  -n supabase \
  --timeout=600s
```

Expected pods:
- 1-3 PostgreSQL pods (depending on `numberOfInstances`)
- Connection pooler pods (if enabled: PgBouncer or Supavisor)
- Auth, REST, Realtime, Storage, Studio, Kong, Meta, Analytics, Functions services

### Step 7: Access Services

#### Port Forward (Development)

```bash
# API Gateway
kubectl port-forward -n supabase svc/supabase-kong 8000:8000

# Studio Dashboard
kubectl port-forward -n supabase svc/supabase-studio 3000:3000
```

Access:
- **API**: http://localhost:8000
- **Studio**: http://localhost:3000

#### Ingress (Production)

If you enabled ingress in values.yaml:

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
```

Access via your configured domain.

### Step 8: Retrieve Database Credentials

The Zalando operator auto-generates random passwords for all database users.

```bash
# Get postgres superuser password
kubectl get secret postgres.my-supabase-db.credentials.postgresql.acid.zalan.do \
  -n supabase \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Get supabase_admin password
kubectl get secret supabase-admin.my-supabase-db.credentials.postgresql.acid.zalan.do \
  -n supabase \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

## Post-Installation

### Verify Installation

```bash
# Check all pods are running
kubectl get pods -n supabase

# Check PostgreSQL cluster status
kubectl get postgresql -n supabase

# Check services
kubectl get svc -n supabase

# Check ingresses (if enabled)
kubectl get ingress -n supabase
```

### Test Database Connection

```bash
# Port-forward PostgreSQL
kubectl port-forward -n supabase svc/my-supabase-db-rw 5432:5432

# Connect with psql (in another terminal)
PGPASSWORD='<password-from-step-8>' psql \
  -h localhost \
  -U supabase_admin \
  -d postgres
```

### Test API Access

```bash
# Port-forward Kong
kubectl port-forward -n supabase svc/supabase-kong 8000:8000

# Test REST API (in another terminal)
curl http://localhost:8000/rest/v1/ \
  -H "apikey: <your-anon-key>" \
  -H "Authorization: Bearer <your-anon-key>"
```

## Configuration Options

### Storage Configuration

See [examples/storage/README.md](../examples/storage/README.md) for detailed storage setup options.

### High Availability

For HA setup, ensure:

```yaml
postgresql:
  numberOfInstances: 3
  patroni:
    synchronous_mode: true
    synchronous_mode_strict: false
```

### Resource Tuning

Adjust based on your workload:

```yaml
postgresql:
  resources:
    requests:
      memory: "4Gi"
      cpu: "2000m"
    limits:
      memory: "8Gi"
      cpu: "4000m"

auth:
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
```

### Email Configuration

For production, configure SMTP:

```yaml
secret:
  smtp:
    host: "smtp.sendgrid.net"
    port: "587"
    user: "apikey"
    pass: "your-sendgrid-api-key"
    adminEmail: "admin@yourdomain.com"
    senderName: "Your App Name"
```

## Multiple Environments

Deploy separate instances for dev, staging, and production:

```bash
# Development
helm install supabase-dev ./helm-charts/supabase-ha \
  --namespace dev-supabase \
  --create-namespace \
  --values examples/development/values.yaml

# High Availability / Production
helm install supabase-prod ./helm-charts/supabase-ha \
  --namespace prod-supabase \
  --create-namespace \
  --values examples/high-availability/values.yaml
```

## Troubleshooting

### Operator Not Found

```bash
# Verify operator is installed
kubectl get deployment -n postgres-operator

# Check operator logs
kubectl logs -n postgres-operator deployment/postgres-operator
```

### PostgreSQL Cluster Stuck

```bash
# Check operator logs
kubectl logs -n postgres-operator deployment/postgres-operator --tail=100

# Check PostgreSQL CR events
kubectl describe postgresql <cluster-name> -n supabase

# Check pod events
kubectl describe pod <pod-name> -n supabase
```

### Storage Issues

```bash
# Check PVCs
kubectl get pvc -n supabase

# Describe PVC to see binding issues
kubectl describe pvc <pvc-name> -n supabase

# Verify storage class exists
kubectl get storageclass
```

### Service Connection Issues

```bash
# Verify secrets exist
kubectl get secrets -n supabase | grep postgresql.acid.zalan.do

# Check service logs
kubectl logs -n supabase deployment/<service-name>

# Check init containers
kubectl logs -n supabase pod/<pod-name> -c wait-for-db
```

For more troubleshooting, see [examples/README.md](../examples/README.md).

## Next Steps

- Configure backups: [WAL-G Configuration](https://github.com/zalando/spilo#wal-e)
- Set up monitoring: Add Prometheus postgres-exporter
- Configure ingress with TLS
- Review security settings
- Plan upgrade strategy

## Uninstallation

```bash
# Delete Supabase deployment
helm uninstall supabase -n supabase

# Delete PostgreSQL cluster (if not deleted by Helm)
kubectl delete postgresql <cluster-name> -n supabase

# Delete namespace
kubectl delete namespace supabase

# Optionally, uninstall operator (affects all PostgreSQL clusters)
helm uninstall postgres-operator -n postgres-operator
kubectl delete namespace postgres-operator
```

**Note**: PersistentVolumes may be retained depending on reclaim policy. Check and manually delete if needed.
