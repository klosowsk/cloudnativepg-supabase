# Supabase HA Kubernetes

**Deploy Supabase with High Availability PostgreSQL on Kubernetes**

Production-ready Supabase deployment using Zalando Postgres Operator for true high availability, automatic failover, and enterprise-grade PostgreSQL management.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15.8-blue.svg)](https://www.postgresql.org/)
[![Supabase](https://img.shields.io/badge/Supabase-1.085-green.svg)](https://supabase.com/)

## ✨ Features

- **High Availability PostgreSQL** - Automatic failover with Patroni (3-node clusters)
- **All-in-One Deployment** - Database and Supabase services in the same namespace
- **Auto-Secret Discovery** - Automatically configures Zalando-generated database credentials
- **Multi-Environment Ready** - Single Helm chart for dev, staging, and production
- **Production Grade** - Built on battle-tested Zalando Postgres Operator and Spilo
- **Complete Supabase Stack** - All official services: Auth, Storage, Realtime, Functions, etc.
- **GitOps Ready** - Works seamlessly with ArgoCD, Flux, or direct Helm
- **Custom Extensions** - Pre-loaded with all Supabase extensions + pgvector, PostGIS, TimescaleDB

## 🚀 Quick Start

### Prerequisites

- Kubernetes 1.21+
- Helm 3.8+
- kubectl configured

### Installation

```bash
# 1. Install Zalando Postgres Operator (once per cluster)
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm install postgres-operator postgres-operator-charts/postgres-operator \
  --namespace postgres-operator \
  --create-namespace

# 2. Verify operator is running
kubectl get pods -n postgres-operator

# 3. Install Supabase Production Instance
helm install supabase-prod ./helm-charts/supabase-ha \
  --namespace prod-supabase \
  --create-namespace \
  --values examples/high-availability/values.yaml

# 4. Wait for PostgreSQL cluster to be ready
kubectl wait --for=condition=ready pod -l cluster-name=prod-supabase-db \
  -n prod-supabase --timeout=300s

# 5. Get auto-generated database password
kubectl get secret supabase-admin.prod-supabase-db.credentials.postgresql.acid.zalan.do \
  -n prod-supabase -o jsonpath='{.data.password}' | base64 -d && echo
```

### Access Supabase

```bash
# Port-forward Kong API Gateway
kubectl port-forward -n prod-supabase svc/kong 8000:8000

# Port-forward Studio Dashboard
kubectl port-forward -n prod-supabase svc/studio 3000:3000

# Access:
# - API: http://localhost:8000
# - Studio: http://localhost:3000
```

## 🏗️ Architecture

### Two-Tier Design

```
┌─────────────────────────────────────────────────────────┐
│  Tier 1: Postgres Operator (Cluster-Scoped)             │
│  Install once per cluster, manages all PostgreSQL CRDs  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Tier 2: Supabase HA (Namespace-Scoped)                 │
│  Install per environment (dev, staging, prod)           │
│                                                         │
│  • PostgreSQL Cluster (1-3 nodes with Patroni)          │
│  • Supabase Services (Auth, REST, Storage, etc.)        │
│  • Deployed together in same namespace                  │
└─────────────────────────────────────────────────────────┘
```

### What Makes This Unique

- **High Availability + Supabase Stack** - Production-grade PostgreSQL HA combined with complete Supabase ecosystem
- **Accessible PostgreSQL** - Enterprise database reliability without operational complexity
- **Data Safety First** - Battle-tested Zalando operator with automatic failover and backup capabilities
- **Kubernetes-Native** - Seamless scaling, self-healing, and cloud-agnostic deployment
- **Community-Driven** - Open source, self-hosted solution with full control over your data

### Components

| Component | Purpose | HA |
|-----------|---------|-----|
| **PostgreSQL Cluster** | Spilo + Patroni for automatic failover | ✅ 3 nodes |
| **Connection Pooler** | PgBouncer or Supavisor (optional) | ✅ 2-3 instances |
| **Auth (GoTrue)** | User authentication | ✅ Stateless |
| **REST (PostgREST)** | Automatic REST API | ✅ Stateless |
| **Realtime** | WebSocket subscriptions | ✅ Stateless |
| **Storage** | File storage (external object storage) | ✅ Stateless |
| **Studio** | Admin dashboard | ✅ Stateless |
| **Kong** | API Gateway | ✅ Stateless |
| **Functions** | Edge Functions runtime | ✅ Stateless |
| **Analytics** | Logflare analytics | ✅ Stateless |

## 📦 What's Included

### Custom Spilo PostgreSQL Image

Pre-loaded with all Supabase extensions:

- **Supabase Core**: pgsodium, pg_net, supabase_vault, pg_graphql
- **AI/ML**: pgvector (vector similarity search)
- **Geospatial**: PostGIS
- **Time-Series**: TimescaleDB
- **Job Scheduling**: pg_cron
- **And 40+ more extensions**

See [docker/spilo-supabase/](docker/spilo-supabase/) for image details.

### Supabase Services

All official Supabase services are included with production-ready defaults:

- ✅ Studio Dashboard
- ✅ Auth (GoTrue) with email/OAuth
- ✅ REST API (PostgREST)
- ✅ Realtime subscriptions
- ✅ Storage API with image transforms
- ✅ Edge Functions runtime
- ✅ Analytics (Logflare)
- ✅ Postgres Meta

## 📚 Quick Links

- **[Examples](examples/)** - Deployment configurations and storage setup
- **[Spilo Supabase Image](docker/spilo-supabase/)** - Custom PostgreSQL image with Supabase extensions
- **[Comprehensive Documentation](#-comprehensive-documentation)** - Complete guides below

## 🎯 Deployment Examples

**Note**: These examples are reference configurations. Customize to your specific needs.

### Development

Single PostgreSQL instance, minimal resources:

```bash
helm install supabase-dev ./helm-charts/supabase-ha \
  --namespace dev-supabase \
  --create-namespace \
  --values examples/development/values.yaml
```

- **PostgreSQL**: 1 instance (no HA)
- **Resources**: 512Mi RAM, 0.25 CPU
- **Storage**: 5Gi
- **Example use case**: Local testing, development

### High Availability

Three PostgreSQL instances with full HA:

```bash
helm install supabase-ha ./helm-charts/supabase-ha \
  --namespace ha-supabase \
  --create-namespace \
  --values examples/high-availability/values.yaml
```

- **PostgreSQL**: 3 instances (primary + 2 replicas)
- **Resources**: 4Gi RAM, 2 CPU per instance
- **Storage**: 100Gi with fast SSDs
- **Monitoring**: Optional Prometheus exporters
- **Backups**: Optional WAL archiving
- **Example use case**: Production workloads

## 🔧 Configuration

### Minimal Configuration

```yaml
# values.yaml
global:
  clusterName: "my-supabase-db"

secret:
  jwt:
    anonKey: "your-anon-key"
    serviceKey: "your-service-key"
    secret: "your-jwt-secret"
  dashboard:
    password: "secure-password"

postgresql:
  dockerImage: klosowsk/spilo-supabase:15.8.1.085-3.2-p1
  numberOfInstances: 3

kong:
  ingress:
    enabled: true
    hosts:
      - host: api.yourdomain.com
```

See [examples/](examples/) for complete configuration examples.

## 🔐 Secret Management

### Auto-Generated Secrets

Zalando operator automatically creates secrets for all database users:

```
{username}.{cluster-name}.credentials.postgresql.acid.zalan.do
```

Example:
```
supabase-admin.prod-supabase-db.credentials.postgresql.acid.zalan.do
authenticator.prod-supabase-db.credentials.postgresql.acid.zalan.do
```

### Retrieve Credentials

```bash
# Get postgres superuser password
kubectl get secret postgres.prod-supabase-db.credentials.postgresql.acid.zalan.do \
  -n prod-supabase -o jsonpath='{.data.password}' | base64 -d

# Get supabase_admin password
kubectl get secret supabase-admin.prod-supabase-db.credentials.postgresql.acid.zalan.do \
  -n prod-supabase -o jsonpath='{.data.password}' | base64 -d
```

### Auto-Discovery

Helm chart automatically discovers and configures these secrets for all Supabase services. No manual configuration required!

## 🚢 GitOps Deployment

### ArgoCD Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: supabase-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/supabase-ha-kubernetes
    targetRevision: main
    path: helm-charts/supabase-ha
    helm:
      valueFiles:
        - ../../examples/production/values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: prod-supabase
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## 🔄 Upgrading

```bash
# Upgrade Supabase services (safe, stateless)
helm upgrade supabase-prod ./helm-charts/supabase-ha \
  --namespace prod-supabase \
  --values examples/high-availability/values.yaml

# Upgrade PostgreSQL version (requires planning)
# Consult Zalando Postgres Operator documentation for major version upgrades
```

## 📊 Monitoring

### Prometheus Integration

PostgreSQL metrics are exported automatically when sidecars are enabled:

```yaml
postgresql:
  sidecars:
    - name: postgres-exporter
      image: quay.io/prometheuscommunity/postgres-exporter:latest
      ports:
        - name: metrics
          containerPort: 9187
```

Access metrics:
```bash
kubectl port-forward -n prod-supabase pod/prod-supabase-db-0 9187:9187
curl http://localhost:9187/metrics
```

## 🧪 Testing

```bash
# Install dev environment
helm install supabase-test ./helm-charts/supabase-ha \
  --namespace test-supabase \
  --create-namespace \
  --values examples/development/values.yaml

# Wait for ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=supabase-ha \
  -n test-supabase --timeout=300s

# Run tests
kubectl exec -n test-supabase supabase-test-db-0 -c postgres -- \
  psql -U postgres -c "SELECT * FROM pg_available_extensions;"

# Cleanup
helm uninstall supabase-test -n test-supabase
kubectl delete namespace test-supabase
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

### Development Setup

```bash
# Clone repository
git clone https://github.com/your-org/supabase-ha-kubernetes
cd supabase-ha-kubernetes

# Build custom Spilo image
cd docker/spilo-supabase
./build.sh

# Test Helm chart
helm lint ./helm-charts/supabase-ha
helm template supabase ./helm-charts/supabase-ha \
  --values examples/development/values.yaml > test-output.yaml
```

## 📖 Comprehensive Documentation

For detailed guides and references:

- **[Installation Guide](docs/installation.md)** - Complete setup instructions with prerequisites and post-installation steps
- **[Configuration Reference](docs/configuration.md)** - All configuration options for PostgreSQL, services, and secrets
- **[Architecture](docs/architecture.md)** - System design, components, HA setup, and data flow
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions for all components
- **[Examples Guide](examples/README.md)** - Deployment scenarios and storage configuration

## 📝 License

Apache License 2.0 - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

This project builds on excellent work from:

- **[Zalando Postgres Operator](https://github.com/zalando/postgres-operator)** - Production-grade PostgreSQL on Kubernetes
- **[Spilo](https://github.com/zalando/spilo)** - HA PostgreSQL with Patroni
- **[Supabase](https://github.com/supabase)** - Open source Firebase alternative
- **[Supabase Kubernetes Community](https://github.com/supabase-community/supabase-kubernetes)** - Original Kubernetes charts
- **[Pigsty](https://pigsty.io/)** - PostgreSQL extension repository

## 🔗 Links

- [Supabase Documentation](https://supabase.com/docs)
- [Zalando Postgres Operator Docs](https://postgres-operator.readthedocs.io/)
- [Spilo Documentation](https://github.com/zalando/spilo)
- [Patroni Documentation](https://patroni.readthedocs.io/)

---

**Built for the Supabase and Kubernetes communities**
