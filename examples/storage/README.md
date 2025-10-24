# Storage Configuration Guide

This directory contains example storage configurations for deploying Supabase with persistent PostgreSQL data.

## Important

**StorageClasses and PersistentVolumes are not part of the Helm chart.** You must deploy storage infrastructure separately before installing Supabase.

### Why This Separation?

- **StorageClass** = Cluster-wide infrastructure resource
- **PersistentVolume** = Physical storage provisioning (only for static provisioning)
- **Helm Chart** = Application layer that references existing storage

The Helm chart only:
- ✅ Creates the PostgreSQL cluster CRD (which references your StorageClass)
- ✅ Zalando operator automatically creates PVCs
- ✅ Kubernetes automatically binds PVCs to PVs

You must:
- ✅ Deploy StorageClass (before Helm install)
- ✅ Deploy PVs (only if using static provisioning)

---

## Choose Your Storage Strategy

### Option 1: Dynamic Provisioning (Recommended)

**Best for:** Cloud providers, Longhorn, Rook-Ceph

Volumes are created automatically when PostgreSQL cluster starts.

**Advantages:**
- No manual PV creation needed
- Automatic provisioning
- Easy scaling

**Requirements:**
- Storage backend (cloud provider, Longhorn, etc.)
- May incur cloud costs

**Examples:**
- [Longhorn](./longhorn/storageclass.yaml) - For on-prem/homelab with multi-node replication
- [AWS EBS](./cloud/aws-gp3.yaml) - For AWS EKS
- [Azure Disk](./cloud/azure-disk.yaml) - For Azure AKS
- [GCP Persistent Disk](./cloud/gcp-pd.yaml) - For Google GKE

---

### Option 2: Local Static Provisioning

**Best for:** K3s, homelab, on-premise with local disks

You manually pre-provision PersistentVolumes on specific nodes.

**Advantages:**
- Fast (local SSD/NVMe)
- No network overhead
- Full control

**Limitations:**
- Data tied to specific nodes
- Manual PV creation for each PostgreSQL instance
- Node failure makes data inaccessible until recovery

**Examples:**
- [Local StorageClass](./local-static/storageclass.yaml)
- [PV Template](./local-static/pv-example.yaml)

**When to use:**
- K3s/K8s homelab clusters
- HA setup with 2-3 nodes
- Have good backup strategy (WAL archiving to S3/MinIO)

---

### Option 3: Ephemeral Storage (Development Only)

**Best for:** Local development, CI/CD testing

No persistent storage - data is lost on pod restart.

**Configuration:**
```yaml
postgresql:
  volume:
    size: 2Gi
    storageClass: ""  # Empty string = ephemeral
```

**Use cases:**
- Local development
- Automated testing
- Short-lived environments

---

## Deployment Workflows

### Workflow 1: Dynamic Provisioning (Cloud/Longhorn)

```bash
# 1. Deploy StorageClass (if not using default)
kubectl apply -f storage/longhorn/storageclass.yaml

# 2. Verify StorageClass exists
kubectl get storageclass

# 3. Deploy Supabase (references the StorageClass)
helm install supabase ./helm-charts/supabase-ha \
  --namespace prod-supabase \
  --create-namespace \
  --set postgresql.volume.storageClass=longhorn \
  --values examples/production/values.yaml
```

**What happens:**
1. Zalando operator creates PVCs automatically
2. Longhorn/Cloud provider creates PVs dynamically
3. Kubernetes binds PVCs to PVs
4. PostgreSQL pods start with persistent storage

---

### Workflow 2: Local Static Provisioning (K3s/Homelab)

```bash
# 1. Deploy StorageClass
kubectl apply -f storage/local-static/storageclass.yaml

# 2. Create PVs (one per PostgreSQL instance)
# Edit pv-example.yaml first:
#   - Set correct node hostnames
#   - Set correct storage paths
#   - Match numberOfInstances in your values.yaml
kubectl apply -f storage/local-static/pv-example.yaml

# 3. Verify PVs are available
kubectl get pv

# 4. Deploy Supabase
helm install supabase ./helm-charts/supabase-ha \
  --namespace prod-supabase \
  --create-namespace \
  --set postgresql.volume.storageClass=supabase-local \
  --values examples/production/values.yaml
```

**What happens:**
1. Zalando operator creates PVCs automatically
2. Kubernetes binds PVCs to your pre-created PVs (matching storageClass + size + node affinity)
3. PostgreSQL pods scheduled on correct nodes
4. Pods mount persistent local storage

---

### Workflow 3: Ephemeral Storage (Development)

```bash
# No storage setup needed!

# Deploy Supabase with ephemeral storage
helm install supabase-dev ./helm-charts/supabase-ha \
  --namespace dev-supabase \
  --create-namespace \
  --values examples/development/values-ephemeral.yaml
```

**What happens:**
1. Zalando operator creates PVCs with no storageClass
2. Kubernetes creates emptyDir volumes (in-memory or node's local disk)
3. Data is lost when pods restart

---

## Storage Sizing Guide

### Development
```yaml
postgresql:
  numberOfInstances: 1
  volume:
    size: 2Gi
    storageClass: ""  # Ephemeral
```

### Staging
```yaml
postgresql:
  numberOfInstances: 2  # 1 primary + 1 replica
  volume:
    size: 20Gi
    storageClass: staging-local  # Or longhorn
```

### Production
```yaml
postgresql:
  numberOfInstances: 3  # 1 primary + 2 replicas
  volume:
    size: 100Gi
    storageClass: production-ssd  # Fast storage
```

---

## Troubleshooting

### PVC stuck in "Pending" state

```bash
kubectl describe pvc <pvc-name> -n <namespace>
```

**Common causes:**
1. **No matching PV** - Check storageClass matches
2. **Size mismatch** - PV must be >= PVC size
3. **No available nodes** - Check node affinity in PVs
4. **StorageClass doesn't exist** - Create it first

### PostgreSQL pod not starting

```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
```

**Common causes:**
1. **Volume mount failures** - Check PV path exists on node
2. **Permission denied** - Check spiloFSGroup matches directory permissions
3. **Node affinity** - Pod can't schedule because PV is on wrong node

### Data not persisting after pod restart

**Check:**
1. Is `storageClass: ""` ? This means ephemeral storage
2. Is PVC bound to a PV? `kubectl get pvc -n <namespace>`
3. Is PV reclaimPolicy "Delete"? Should be "Retain" for production

---

## Migration Between Storage Types

### From Ephemeral to Persistent

1. **Backup your data** (if any exists)
2. **Delete ephemeral deployment**
3. **Setup persistent storage** (StorageClass + PVs if needed)
4. **Deploy with persistent values**
5. **Restore backup** (if needed)

### From Local to Cloud Storage

1. **Use Zalando's backup/restore** (WAL archiving + basebackup)
2. **Deploy new cluster with cloud StorageClass**
3. **Restore from backup**
4. **Switch application endpoints**
5. **Decommission old cluster**

---

## Best Practices

### For Production

- Use dynamic provisioning (Longhorn, Rook-Ceph, or cloud provider)
- Set reclaimPolicy: Retain (keeps data if cluster deleted)
- Enable WAL archiving to S3/MinIO (disaster recovery)
- Use multiple replicas (numberOfInstances: 3)
- Monitor storage usage (set up alerts)

### For Development

- Use ephemeral storage (`storageClass: ""`)
- Single instance (numberOfInstances: 1)
- Small volumes (2-5Gi)

### For Homelab/K3s

- Use local PVs with hostPath
- Pin PVs to specific nodes (nodeAffinity)
- Set up WAL archiving (backup to NAS/external storage)
- Test failover scenarios (node failures, pod evictions)

---

## Next Steps

1. Choose your storage strategy above
2. Follow the deployment workflow for your chosen strategy
3. Deploy storage infrastructure (StorageClass + PVs if static)
4. Install Supabase Helm chart with appropriate values
5. Verify PostgreSQL cluster is running and data persists

For Helm chart configuration, see [examples/README.md](../README.md)
