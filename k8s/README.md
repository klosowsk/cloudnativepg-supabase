# Kubernetes Deployment with Kustomize

Simple Kustomize setup for deploying CloudNativePG Supabase.

## Directory Structure

```
k8s/
├── base/
│   ├── kustomization.yaml      # ConfigMap generator from SQL files
│   ├── cluster.yaml            # CloudNativePG Cluster definition
│   └── init-sql/               # Generated SQL files (4 files)
└── overlays/
    └── dev/
        ├── kustomization.yaml  # Dev environment config
        └── cluster-patch.yaml  # Dev-specific patches
```

## Quick Start

### 1. Generate SQL Files

```bash
./scripts/generate-configmaps.sh
```

This creates 4 SQL files in `k8s/base/init-sql/`:
- `00-master-init.sql` - Main orchestrator
- `01-custom-init.sql` - Custom initialization scripts
- `02-supabase-init.sql` - Supabase init scripts
- `03-supabase-migrations.sql` - All Supabase migrations

### 2. Configure Secrets

Edit `k8s/overlays/dev/kustomization.yaml`:

```yaml
secretGenerator:
- name: supabase-db-secret
  literals:
  - password=YOUR-PASSWORD-HERE
  - jwt-secret=YOUR-JWT-SECRET-MIN-32-CHARS-HERE
```

### 3. Deploy

```bash
# Apply with kubectl
kubectl apply -k k8s/overlays/dev/

# Or preview first
kubectl kustomize k8s/overlays/dev/
```

### 4. Monitor

```bash
# Watch cluster
kubectl get cluster -n supabase-dev supabase-db -w

# Watch logs
kubectl logs -n supabase-dev -f supabase-db-1 -c postgres
```

## ArgoCD Setup

Point your ArgoCD Application to:
- **Path:** `k8s/overlays/dev`
- **Namespace:** `supabase-dev`

Example Application manifest:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: supabase-db
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/klosowsk/cloudnativepg-supabase.git
    targetRevision: main
    path: k8s/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: supabase-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

## Creating New Environments

Copy the dev overlay:

```bash
cp -r k8s/overlays/dev k8s/overlays/production

# Edit the new overlay
vim k8s/overlays/production/kustomization.yaml
vim k8s/overlays/production/cluster-patch.yaml
```

Then point ArgoCD to `k8s/overlays/production`.

## How It Works

1. **Kustomize reads `base/kustomization.yaml`**
   - Generates ConfigMap from SQL files in `init-sql/`
   - Applies base Cluster manifest

2. **Overlay patches are applied**
   - Changes namespace
   - Adjusts resources, instances, storage
   - Generates secrets (dev) or references ExternalSecrets (prod)

3. **CloudNativePG creates cluster**
   - Reads ConfigMap with SQL files
   - Runs migrations via `postInitApplicationSQLRefs`
   - Cluster is ready with full Supabase schema

## Troubleshooting

**ConfigMap not found:**
```bash
# Regenerate SQL files
./scripts/generate-configmaps.sh

# Verify files exist
ls -la k8s/base/init-sql/
```

**Kustomize build fails:**
```bash
# Test build locally
kubectl kustomize k8s/overlays/dev/

# Common issues:
# - SQL files not generated (run generate-configmaps.sh)
# - YAML syntax error (check with yamllint)
```

**Cluster fails to bootstrap:**
```bash
# Check logs
kubectl logs -n supabase-dev supabase-db-1 -c postgres

# Check events
kubectl describe cluster -n supabase-dev supabase-db

# Common issues:
# - Secret not created (check secretGenerator)
# - SQL syntax error (check postgres logs)
# - JWT_SECRET not set (verify cluster.yaml env section)
```
