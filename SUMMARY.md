# Summary of Changes

## Problem Solved

CloudNativePG images **don't use `/docker-entrypoint-initdb.d/`** like standard PostgreSQL Docker images. Our migrations weren't running because CloudNativePG bypasses the Docker entrypoint.

## Solution

Migrated to **Kustomize + separate SQL files** for Kubernetes-native initialization:

### What Was Changed

1. **SQL files separated from YAML**
   - Instead of embedding SQL in ConfigMap YAML (caused syntax errors)
   - Now: 4 separate SQL files in `k8s/base/init-sql/`
   - Kustomize generates ConfigMap from these files

2. **No hardcoded secrets**
   - Instead of plaintext secrets in YAML
   - Now: Use `secretGenerator` in overlays (can reference env vars)
   - Production: Use External Secrets Operator

3. **ArgoCD-ready structure**
   - Point ArgoCD to: `k8s/overlays/dev` (or your overlay)
   - ArgoCD automatically runs Kustomize and deploys

## File Structure

```
k8s/
├── README.md                    # Deployment instructions
├── argocd-application.yaml     # ArgoCD app example
├── base/
│   ├── kustomization.yaml      # Generates ConfigMap from SQL files
│   ├── cluster.yaml            # CloudNativePG Cluster
│   └── init-sql/               # Generated SQL files (4 files)
└── overlays/
    └── dev/
        ├── kustomization.yaml  # Environment config + secret generator
        └── cluster-patch.yaml  # Dev-specific settings
```

## How to Use

### 1. Generate SQL Files

```bash
./scripts/generate-configmaps.sh
```

### 2. Configure Secrets

Edit `k8s/overlays/dev/kustomization.yaml`:

```yaml
secretGenerator:
- name: supabase-db-secret
  literals:
  - password=YOUR-PASSWORD
  - jwt-secret=YOUR-JWT-SECRET
```

### 3. Deploy

**With kubectl:**
```bash
kubectl apply -k k8s/overlays/dev/
```

**With ArgoCD:**
Point your Application to `k8s/overlays/dev` - that's it!

## Benefits

✅ **No YAML syntax errors** - SQL files are pure SQL, no escaping needed
✅ **No hardcoded secrets** - Use secretGenerator or External Secrets
✅ **GitOps-ready** - ArgoCD natively supports Kustomize
✅ **Easy to review** - SQL files are separate and readable
✅ **Namespace support** - Each overlay can use different namespace

## For Your Local ArgoCD

Just commit and point ArgoCD to:
- **Path:** `k8s/overlays/dev`
- **Namespace:** `supabase-dev` (or whatever you want)

Done!
