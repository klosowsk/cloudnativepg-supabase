# Troubleshooting Guide

Common issues and solutions for Supabase HA Kubernetes deployments.

## PostgreSQL Issues

### Cluster Won't Start

**Symptoms**: PostgreSQL pods stuck in `Pending`, `Init`, or `CrashLoopBackOff`.

**Diagnosis**:

```bash
# Check operator logs
kubectl logs -n postgres-operator deployment/postgres-operator --tail=100

# Check PostgreSQL CR status
kubectl describe postgresql <cluster-name> -n <namespace>

# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace>
```

**Common Causes**:

#### 1. PVC Pending

```bash
kubectl get pvc -n <namespace>
```

**Solutions**:
- Verify StorageClass exists: `kubectl get storageclass`
- Check storage provisioner is running
- For local storage, ensure PVs are created with correct size and node affinity
- See [examples/storage/README.md](../examples/storage/README.md)

#### 2. Insufficient Resources

```bash
kubectl describe pod <pod-name> -n <namespace> | grep -A5 "Events:"
```

**Solutions**:
- Check node resources: `kubectl top nodes`
- Reduce resource requests in values.yaml
- Add more nodes to cluster

#### 3. Image Pull Errors

```bash
kubectl describe pod <pod-name> -n <namespace> | grep "Failed to pull"
```

**Solutions**:
- Verify image name: `postgresql.dockerImage` in values.yaml
- Check image exists: `docker pull <image-name>`
- Configure imagePullSecrets if using private registry

#### 4. Init Container Failures

```bash
kubectl logs <pod-name> -n <namespace> -c <init-container-name>
```

**Solutions**:
- Check JWT secret exists: `kubectl get secret supabase-jwt-config -n <namespace>`
- Verify secret format matches expected keys
- Check init container permissions

### Cluster Stuck in "Creating" or "SyncFailed"

**Diagnosis**:

```bash
kubectl get postgresql <cluster-name> -n <namespace>
```

**Solutions**:

1. Check operator configuration:
```bash
kubectl get configmap postgres-operator -n postgres-operator -o yaml
```

2. Verify operator has RBAC permissions:
```bash
kubectl auth can-i create statefulsets \
  --as=system:serviceaccount:postgres-operator:postgres-operator \
  -n <namespace>
```

3. Check operator logs for errors:
```bash
kubectl logs -n postgres-operator deployment/postgres-operator | grep ERROR
```

### Replication Lag or Broken Replication

**Diagnosis**:

```bash
# Check Patroni cluster status
kubectl exec -n <namespace> <pod-name> -c postgres -- patronictl list

# Check replication status in PostgreSQL
kubectl exec -n <namespace> <pod-name> -c postgres -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

**Solutions**:

1. Verify network connectivity between pods
2. Check pg_hba.conf allows replication
3. Restart replica pod to resync:
```bash
kubectl delete pod <replica-pod-name> -n <namespace>
```

### Failover Not Happening

**Symptoms**: Primary pod fails but no promotion occurs.

**Diagnosis**:

```bash
# Check Patroni configuration
kubectl exec -n <namespace> <pod-name> -c postgres -- \
  patronictl show-config

# Check DCS (Distributed Configuration Store) connectivity
kubectl logs <pod-name> -n <namespace> -c postgres | grep "DCS"
```

**Solutions**:

1. Verify Patroni endpoints are accessible between pods
2. Check network policies aren't blocking pod-to-pod communication
3. Verify minimum quorum is available (need majority of nodes)

## Service Connection Issues

### Services Can't Connect to Database

**Symptoms**: Service pods show database connection errors in logs.

**Diagnosis**:

```bash
# Check if secrets exist
kubectl get secrets -n <namespace> | grep postgresql.acid.zalan.do

# Check service logs
kubectl logs -n <namespace> deployment/<service-name> --tail=50
```

**Solutions**:

#### 1. Secrets Don't Exist Yet

Zalando operator creates secrets asynchronously. Wait 30-60 seconds after PostgreSQL cluster creation.

```bash
# Wait for cluster to be ready
kubectl wait --for=condition=ready pod \
  -l cluster-name=<cluster-name> \
  -n <namespace> \
  --timeout=300s
```

#### 2. Wrong Secret Reference

Check service deployment:
```bash
kubectl get deployment <service-name> -n <namespace> -o yaml | grep secretKeyRef
```

Verify secret name matches Zalando pattern:
```
{username}.{cluster-name}.credentials.postgresql.acid.zalan.do
```

#### 3. Database User Doesn't Exist

```bash
# Connect to database
kubectl exec -it <pod-name> -n <namespace> -c postgres -- \
  psql -U postgres -c "\du"
```

If user missing, check PostgreSQL CR `users` section in values.yaml.

### Init Containers Stuck Waiting for Database

**Symptoms**: Pods stuck in `Init:0/1` state.

**Diagnosis**:

```bash
kubectl logs <pod-name> -n <namespace> -c wait-for-db
```

**Solutions**:

1. Verify PostgreSQL service exists:
```bash
kubectl get svc <cluster-name>-rw -n <namespace>
```

2. Test database connectivity from init container:
```bash
kubectl debug <pod-name> -n <namespace> -it --image=postgres:15-alpine -- \
  psql -h <cluster-name>-rw -U postgres -c "SELECT 1;"
```

3. Check PostgreSQL is actually ready:
```bash
kubectl exec -n <namespace> <pg-pod-name> -c postgres -- \
  pg_isready -U postgres
```

## Storage Issues

### PVC Stuck in Pending

**Diagnosis**:

```bash
kubectl describe pvc <pvc-name> -n <namespace>
```

**Common Causes**:

#### 1. No Matching PV (Static Provisioning)

```bash
kubectl get pv
```

**Solutions**:
- Create PV with matching size, storageClass, and access modes
- For local storage, ensure node affinity matches
- See [examples/storage/local-static/](../examples/storage/local-static/)

#### 2. StorageClass Doesn't Exist

```bash
kubectl get storageclass
```

**Solutions**:
- Create StorageClass before deploying
- Or use existing StorageClass name in values.yaml

#### 3. Provisioner Not Running

```bash
# For Longhorn
kubectl get pods -n longhorn-system

# For other provisioners, check their namespace
```

**Solutions**:
- Install and configure storage provisioner
- Check provisioner logs for errors

### Permission Denied on Volume Mount

**Symptoms**: PostgreSQL pod logs show permission errors.

**Diagnosis**:

```bash
kubectl logs <pod-name> -n <namespace> -c postgres | grep -i permission
```

**Solutions**:

1. For local volumes, set correct ownership on host:
```bash
# On Kubernetes node
sudo chown -R 101:103 /path/to/volume
sudo chmod 700 /path/to/volume
```

2. Verify fsGroup and runAsUser in values.yaml:
```yaml
postgresql:
  podAnnotations:
    "spiloRunAsUser": "101"
    "spiloRunAsGroup": "103"
    "spiloFSGroup": "103"
```

### Data Not Persisting

**Symptoms**: Data lost after pod restart.

**Diagnosis**:

```bash
# Check PVC is bound
kubectl get pvc -n <namespace>

# Check PV reclaim policy
kubectl get pv -o custom-columns=NAME:.metadata.name,RECLAIM:.spec.persistentVolumeReclaimPolicy
```

**Solutions**:

1. Ensure storageClass is set (not empty string):
```yaml
postgresql:
  volume:
    storageClass: "your-storage-class"  # Not ""
```

2. Set PV reclaimPolicy to "Retain" for production:
```bash
kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

## Ingress Issues

### Ingress Not Working

**Symptoms**: Cannot access services via ingress hostname.

**Diagnosis**:

```bash
# Check ingress exists
kubectl get ingress -n <namespace>

# Describe ingress
kubectl describe ingress <ingress-name> -n <namespace>

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=100
```

**Solutions**:

#### 1. Ingress Controller Not Installed

```bash
# Install nginx ingress controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

#### 2. DNS Not Configured

Ensure DNS points to ingress controller LoadBalancer IP:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

#### 3. TLS Certificate Issues

```bash
# Check TLS secret exists
kubectl get secret <tls-secret-name> -n <namespace>

# Describe ingress to see TLS configuration
kubectl describe ingress <ingress-name> -n <namespace>
```

## Performance Issues

### High CPU Usage on PostgreSQL

**Diagnosis**:

```bash
# Check resource usage
kubectl top pods -n <namespace>

# Check active connections
kubectl exec -n <namespace> <pod-name> -c postgres -- \
  psql -U postgres -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"
```

**Solutions**:

1. Increase resource limits in values.yaml
2. Enable connection pooling (PgBouncer or Supavisor)
3. Optimize queries (check `pg_stat_statements`)
4. Add read replicas and load balance reads

### Slow Query Performance

**Diagnosis**:

```bash
# Enable pg_stat_statements
kubectl exec -n <namespace> <pod-name> -c postgres -- \
  psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

# Check slow queries
kubectl exec -n <namespace> <pod-name> -c postgres -- \
  psql -U postgres -c "SELECT query, calls, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"
```

**Solutions**:

1. Add indexes
2. Optimize queries
3. Increase shared_buffers and work_mem
4. Enable query caching

### Connection Pool Exhaustion

**Symptoms**: "Too many connections" errors.

**Diagnosis**:

```bash
# Check current connections
kubectl exec -n <namespace> <pod-name> -c postgres -- \
  psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Check max connections
kubectl exec -n <namespace> <pod-name> -c postgres -- \
  psql -U postgres -c "SHOW max_connections;"
```

**Solutions**:

1. Increase max_connections in PostgreSQL parameters:
```yaml
postgresql:
  parameters:
    max_connections: "200"
```

2. Scale connection pooler:
```yaml
postgresql:
  connectionPooler:
    numberOfInstances: 3
```

3. Configure application connection pools properly

## Backup and Recovery Issues

### WAL Archiving Failing

**Diagnosis**:

```bash
# Check PostgreSQL logs
kubectl logs <pod-name> -n <namespace> -c postgres | grep -i "wal"

# Check object storage credentials
kubectl get secret <storage-secret> -n <namespace> -o yaml
```

**Solutions**:

1. Verify storage bucket/container exists and is accessible
2. Check storage credentials are correct
3. Ensure network connectivity to storage endpoint
4. Verify permissions for storage bucket/container

### Restore Fails

**Diagnosis**:

```bash
kubectl logs <pod-name> -n <namespace> -c postgres | grep -i restore
```

**Solutions**:

1. Verify backup exists in object storage
2. Check restore configuration in values.yaml
3. Ensure sufficient storage for restored data
4. Check restore user has correct permissions

## Upgrade Issues

### Helm Upgrade Fails

**Diagnosis**:

```bash
# Check Helm release status
helm status <release-name> -n <namespace>

# Check what would change
helm diff upgrade <release-name> ./helm-charts/supabase-ha \
  --namespace <namespace> \
  --values values.yaml
```

**Solutions**:

1. Check for breaking changes in chart
2. Review values.yaml for deprecated fields
3. Back up data before upgrade
4. Use `--force` flag if necessary (caution!)

### PostgreSQL Version Upgrade Fails

**Symptoms**: PostgreSQL won't start after version upgrade.

**Important**: Major PostgreSQL version upgrades require special handling:

1. Backup all data
2. Use pg_upgrade or logical replication
3. Test in staging environment first
4. See [Zalando documentation](https://postgres-operator.readthedocs.io/en/latest/administrator/#minor-and-major-version-upgrade)

## Getting Help

### Collect Diagnostic Information

```bash
# Get all resources
kubectl get all -n <namespace>

# Describe PostgreSQL cluster
kubectl describe postgresql <cluster-name> -n <namespace>

# Get operator logs
kubectl logs -n postgres-operator deployment/postgres-operator --tail=200

# Get pod logs
kubectl logs <pod-name> -n <namespace> --all-containers

# Get events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Enable Debug Logging

For PostgreSQL:
```yaml
postgresql:
  parameters:
    log_min_messages: "DEBUG1"
    log_min_duration_statement: "0"  # Log all queries
```

For services, set environment variables:
```yaml
<service>:
  environment:
    LOG_LEVEL: "debug"
```

### Report Issues

When reporting issues, include:

1. Kubernetes version: `kubectl version --short`
2. Helm version: `helm version --short`
3. Chart version: `helm list -n <namespace>`
4. Values file (sanitize secrets!)
5. Error logs from pods and operator
6. Output of diagnostic commands above

### Resources

- [Zalando Postgres Operator Docs](https://postgres-operator.readthedocs.io/)
- [Spilo Troubleshooting](https://github.com/zalando/spilo/blob/master/TROUBLESHOOTING.md)
- [Supabase Discord](https://discord.supabase.com/)
- [GitHub Issues](https://github.com/your-org/supabase-ha-kubernetes/issues)
