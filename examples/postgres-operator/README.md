# Postgres Operator Installation

Before deploying Supabase HA, you must install the Zalando Postgres Operator. This operator manages the PostgreSQL clusters for all your Supabase instances.

## Overview

The Postgres Operator is **cluster-scoped** and should be installed **once per Kubernetes cluster**. It will:
- Watch for PostgreSQL CRDs in all namespaces
- Create and manage PostgreSQL clusters (Spilo + Patroni)
- Generate database user secrets automatically
- Handle failover and high availability

After installation, you can deploy multiple Supabase instances in different namespaces, and the operator will manage all of them.

## Installation

### Using Helm

Use the provided installation script:

```bash
./helm-install.sh
```

Or install manually:

```bash
# Add Helm repository
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm repo update

# Install with custom values
helm install postgres-operator postgres-operator-charts/postgres-operator \
  --namespace postgres-operator \
  --create-namespace \
  --values values.yaml
```

This will:
- Create the `postgres-operator` namespace
- Install the operator from official Helm chart
- Configure it to watch all namespaces

## Verification

### Check Operator Pod

```bash
kubectl get pods -n postgres-operator
```

Expected output:
```
NAME                                 READY   STATUS    RESTARTS   AGE
postgres-operator-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
```

### Check Operator Logs

```bash
kubectl logs -n postgres-operator deployment/postgres-operator
```

Look for:
```
INFO: Successfully registered CRD
INFO: Watching all namespaces
INFO: Postgres Operator started
```

### Verify CRDs

```bash
kubectl get crd | grep postgresql
```

Expected output:
```
postgresqls.acid.zalan.do
```

## Configuration

The `values.yaml` file includes:

### Key Settings

```yaml
configGeneral:
  enable_crd_registration: true      # Register CRDs automatically
  docker_image: ghcr.io/zalando/spilo-17:4.0-p3  # Default Spilo image
  workers: 2                         # Worker threads

configKubernetes:
  watched_namespace: "*"             # Watch all namespaces
  enable_finalizers: true            # Proper cleanup on deletion
  enable_persistent_volume_claim_deletion: true  # Delete PVCs with cluster
```

### Customization

Edit `values.yaml` to:
- Change worker count for large clusters
- Adjust resource limits
- Configure defaults for PostgreSQL pods
- Enable/disable debugging

## Troubleshooting

### Operator pod not starting

```bash
# Check events
kubectl describe pod -n postgres-operator <pod-name>

# Common issues:
# - Missing RBAC permissions
# - CRD registration failed
# - Image pull errors
```

### CRD not registered

```bash
# Manually install CRDs
kubectl apply -f https://raw.githubusercontent.com/zalando/postgres-operator/master/manifests/postgresql.crd.yaml

# Then upgrade operator
helm upgrade postgres-operator postgres-operator-charts/postgres-operator \
  --namespace postgres-operator
```

### Operator not watching namespaces

Check configuration:
```bash
kubectl get configmap -n postgres-operator postgres-operator -o yaml | grep watched_namespace
```

Should show: `watched_namespace: "*"`

## Next Steps

After the operator is installed and running:

1. **Deploy Development Supabase**:
   ```bash
   helm install supabase-dev ../../helm-charts/supabase-ha \
     --namespace dev-supabase \
     --create-namespace \
     --values ../development/values.yaml
   ```

2. **Deploy High Availability Supabase**:
   ```bash
   helm install supabase-ha ../../helm-charts/supabase-ha \
     --namespace ha-supabase \
     --create-namespace \
     --values ../high-availability/values.yaml
   ```

3. **Verify PostgreSQL Cluster**:
   ```bash
   kubectl get postgresql -n <namespace>
   kubectl get pods -n <namespace>
   ```

## Upgrading

```bash
helm repo update
helm upgrade postgres-operator postgres-operator-charts/postgres-operator \
  --namespace postgres-operator
```

## Uninstalling

**Warning**: Uninstalling the operator will not delete existing PostgreSQL clusters. You must delete them first.

```bash
# 1. Delete all PostgreSQL clusters
kubectl delete postgresql --all --all-namespaces

# 2. Uninstall operator
helm uninstall postgres-operator -n postgres-operator

# 3. (Optional) Delete CRDs
kubectl delete crd postgresqls.acid.zalan.do

# 4. Delete namespace
kubectl delete namespace postgres-operator
```

## Resources

- [Zalando Postgres Operator Documentation](https://postgres-operator.readthedocs.io/)
- [Helm Chart Repository](https://github.com/zalando/postgres-operator/tree/master/charts/postgres-operator)
- [Configuration Reference](https://postgres-operator.readthedocs.io/en/latest/reference/operator_parameters/)
