# Architecture Overview

## System Design

Supabase HA Kubernetes uses a two-tier architecture that separates infrastructure management from application deployment.

### Two-Tier Architecture

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

### Design Benefits

- Database and services deployed in same namespace for simplified secret management
- Battle-tested Zalando operator provides reliable HA and automatic failover
- Kubernetes-native scaling and self-healing capabilities
- Complete Supabase stack with production-ready defaults

## Components

### PostgreSQL High Availability

| Component | Purpose | HA Support |
|-----------|---------|------------|
| **Spilo** | PostgreSQL + Patroni container | ✅ |
| **Patroni** | Automatic failover and cluster management | ✅ |
| **Connection Pooler** | PgBouncer or Supavisor (optional) | ✅ |
| **WAL-G** | Continuous archiving and PITR (optional) | ✅ |

### Supabase Services

All services are stateless and horizontally scalable:

| Service | Purpose | Default Port |
|---------|---------|--------------|
| **Auth (GoTrue)** | User authentication | 9999 |
| **REST (PostgREST)** | Automatic REST API | 3000 |
| **Realtime** | WebSocket subscriptions | 4000 |
| **Storage** | File storage (requires external object storage) | 5000 |
| **Studio** | Admin dashboard | 3000 |
| **Kong** | API Gateway | 8000 |
| **Functions** | Edge Functions runtime | 9000 |
| **Analytics** | Logflare analytics | 4000 |
| **Meta** | Postgres metadata service | 8080 |

## Data Flow

### Secret Management

```
1. Helm chart creates PostgreSQL CRD
   ↓
2. Zalando operator provisions PostgreSQL cluster
   ↓
3. Operator auto-generates secrets:
   - postgres.{cluster}.credentials.postgresql.acid.zalan.do
   - supabase-admin.{cluster}.credentials.postgresql.acid.zalan.do
   - authenticator.{cluster}.credentials.postgresql.acid.zalan.do
   - [additional service users...]
   ↓
4. Helm templates auto-discover secrets
   ↓
5. Services reference secrets via secretKeyRef
   ↓
6. Init containers wait for database readiness
   ↓
7. Services start with auto-configured credentials
```

### Request Flow

```
External Request
  ↓
Ingress (TLS termination)
  ↓
Kong (API Gateway)
  ↓
  ├─→ Auth Service → PostgreSQL (auth schema)
  ├─→ REST Service → PostgreSQL (public schema via RLS)
  ├─→ Realtime Service → PostgreSQL (realtime schema)
  ├─→ Storage Service → PostgreSQL (storage schema) + Object Storage
  └─→ Functions Service → PostgreSQL (functions schema)
```

## High Availability Configuration

### Development (1 Instance)

- **PostgreSQL**: Single instance
- **Resources**: Minimal (512Mi RAM, 0.25 CPU)
- **Storage**: 2-5Gi
- **Failover**: None
- **Example use case**: Local development, testing

### High Availability (3 Instances)

- **PostgreSQL**: 1 primary + 2 replicas
- **Resources**: Production-grade (4Gi RAM, 2 CPU)
- **Storage**: 100Gi+ with fast SSDs
- **Failover**: Automatic via Patroni
- **Replication**: Synchronous streaming replication
- **Example use case**: Production workloads

## Storage Architecture

### PostgreSQL Data

- Persistent volumes for each PostgreSQL instance
- Managed by Kubernetes StatefulSets
- Support for local or cloud storage classes

### File Storage (Supabase Storage)

Requires external object storage. Supported options:
- **S3** - AWS S3 or S3-compatible storage
- **Azure Blob Storage** - Azure cloud storage
- **GCS** - Google Cloud Storage
- **Local path** - File system storage (development only)

## Network Architecture

### Internal Services

All services communicate via Kubernetes ClusterIP services:

```
{service-name}.{namespace}.svc.cluster.local
```

### PostgreSQL Connection Endpoints

- **Primary (read-write)**: `{cluster}-rw.{namespace}.svc.cluster.local:5432`
- **Replicas (read-only)**: `{cluster}-ro.{namespace}.svc.cluster.local:5432`
- **Pooler**: `{cluster}-pooler.{namespace}.svc.cluster.local:5432`

### External Access

Via Ingress controllers:
- Kong API Gateway: `api.yourdomain.com`
- Studio Dashboard: `studio.yourdomain.com`

## Security

### Authentication Layers

1. **API Layer**: JWT tokens validated by Kong
2. **Service Layer**: Service-specific credentials from Zalando secrets
3. **Database Layer**: Row Level Security (RLS) policies

### Database Users

- `postgres` - Superuser (demoted after initial setup)
- `supabase_admin` - Primary administrative user
- `authenticator` - Connection pooler role (can assume: anon, authenticated, service_role)
- `anon` - Unauthenticated API access
- `authenticated` - Authenticated user access
- `service_role` - Backend services (bypasses RLS)

### Secret Storage

All secrets stored in Kubernetes Secrets:
- Auto-generated database credentials (by Zalando operator)
- JWT secrets (user-provided)
- Dashboard passwords (user-provided)
- Object storage credentials (user-provided)

## Backup and Recovery

### Continuous Archiving (Optional)

When configured:
- WAL-G archives Write-Ahead Logs to object storage
- Point-in-time recovery (PITR) capability
- Automatic base backups on schedule

### Backup Strategy (When Enabled)

- **Continuous**: WAL archiving every 16MB
- **Full backups**: Configurable schedule
- **Retention**: Configurable retention policy

## Monitoring and Observability

### Metrics

- PostgreSQL metrics via postgres-exporter (optional)
- Service metrics via native Prometheus endpoints
- Patroni cluster health metrics

### Logging

- Vector log aggregation (optional)
- Supabase Analytics (Logflare)
- Kubernetes pod logs

## Scalability

### Vertical Scaling

Adjust resource requests/limits in values.yaml:
```yaml
postgresql:
  resources:
    requests:
      memory: "8Gi"
      cpu: "4"
```

### Horizontal Scaling

- **PostgreSQL**: Add replicas via `numberOfInstances`
- **Supabase Services**: Increase `replicaCount` for stateless services
- **Connection Pooling**: Scale connection pooler instances (PgBouncer or Supavisor)

## Failure Scenarios

### Primary PostgreSQL Failure

1. Patroni detects primary failure (< 30 seconds)
2. Automatic leader election among replicas
3. New primary promoted
4. Services reconnect automatically
5. Failed pod replaced by StatefulSet

### Service Pod Failure

1. Kubernetes detects pod failure
2. Deployment controller creates replacement pod
3. Pod starts and connects to database
4. Service routing updated automatically

### Node Failure

1. PostgreSQL pods on failed node become unschedulable
2. If primary was on failed node, Patroni promotes replica
3. Kubernetes reschedules pods to healthy nodes
4. PVCs remain available for rescheduled pods

## Differences from Managed Supabase

### Included

- ✅ Complete Supabase database schema
- ✅ All PostgreSQL extensions
- ✅ High availability PostgreSQL
- ✅ Automatic failover
- ✅ Connection pooling
- ✅ Backup and PITR

### Not Included

- ❌ Managed infrastructure
- ❌ Automatic scaling decisions
- ❌ Built-in CDN
- ❌ Managed secrets rotation
- ❌ Global edge network

### You Manage

- Kubernetes cluster
- Storage provisioning
- Ingress/TLS certificates
- Backup storage (object storage)
- Monitoring setup
- Upgrade planning

## References

- [Zalando Postgres Operator Architecture](https://postgres-operator.readthedocs.io/en/latest/reference/cluster_manifest/)
- [Spilo Architecture](https://github.com/zalando/spilo)
- [Patroni Documentation](https://patroni.readthedocs.io/)
- [Supabase Self-Hosting](https://supabase.com/docs/guides/self-hosting)
