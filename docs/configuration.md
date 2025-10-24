# Configuration Reference

Complete reference for configuring Supabase HA Kubernetes deployments.

## Global Configuration

### global

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.clusterName` | PostgreSQL cluster name | `"supabase-db"` |
| `global.autoDiscoverSecrets` | Auto-configure database secret references | `true` |

Example:
```yaml
global:
  clusterName: "prod-supabase-db"
  autoDiscoverSecrets: true
```

## PostgreSQL Configuration

### postgresql

Core PostgreSQL cluster configuration.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Deploy PostgreSQL cluster | `true` |
| `postgresql.teamId` | Team identifier for cluster | `"supabase"` |
| `postgresql.dockerImage` | Spilo container image | `"klosowsk/spilo-supabase:15.8.1.085-3.2-p1"` |
| `postgresql.numberOfInstances` | Number of PostgreSQL replicas | `3` |

Example:
```yaml
postgresql:
  enabled: true
  teamId: "myteam"
  dockerImage: "klosowsk/spilo-supabase:15.8.1.085-3.2-p1"
  numberOfInstances: 3
```

### postgresql.resources

Resource requests and limits for PostgreSQL pods.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.resources.requests.cpu` | CPU request | `"2000m"` |
| `postgresql.resources.requests.memory` | Memory request | `"4Gi"` |
| `postgresql.resources.limits.cpu` | CPU limit | `"4000m"` |
| `postgresql.resources.limits.memory` | Memory limit | `"8Gi"` |

Example:
```yaml
postgresql:
  resources:
    requests:
      cpu: "1000m"
      memory: "2Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"
```

### postgresql.volume

Persistent volume configuration.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.volume.size` | Volume size | `"100Gi"` |
| `postgresql.volume.storageClass` | Storage class name | `""` |

Example:
```yaml
postgresql:
  volume:
    size: "500Gi"
    storageClass: "fast-ssd"
```

### postgresql.users

Database users to create. Users are created automatically with random passwords stored in Kubernetes secrets.

| User | Purpose |
|------|---------|
| `supabase_admin` | Primary admin user (superuser) |
| `authenticator` | Connection pooler role |
| `postgres` | PostgreSQL superuser |

Additional users can be added:

```yaml
postgresql:
  users:
    custom_user: []  # No specific databases
```

### postgresql.databases

Databases to create.

Default:
```yaml
postgresql:
  databases:
    postgres: supabase_admin
```

### postgresql.parameters

PostgreSQL configuration parameters.

Common parameters:

```yaml
postgresql:
  parameters:
    max_connections: "200"
    shared_buffers: "2GB"
    effective_cache_size: "6GB"
    work_mem: "32MB"
    maintenance_work_mem: "512MB"
    random_page_cost: "1.1"
    effective_io_concurrency: "200"
    wal_buffers: "16MB"
    min_wal_size: "1GB"
    max_wal_size: "4GB"
    log_statement: "ddl"
    log_duration: "off"
    log_min_duration_statement: "1000"
```

### postgresql.patroni

Patroni high availability configuration.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.patroni.synchronous_mode` | Enable synchronous replication | `true` |
| `postgresql.patroni.synchronous_mode_strict` | Require sync replica for writes | `false` |

Example:
```yaml
postgresql:
  patroni:
    synchronous_mode: true
    synchronous_mode_strict: false
```

### postgresql.connectionPooler

Connection pooler configuration (PgBouncer). Note: Supavisor is also available as an alternative.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.connectionPooler.numberOfInstances` | Number of pooler instances | `2` |
| `postgresql.connectionPooler.mode` | Pooling mode (session/transaction) | `"transaction"` |
| `postgresql.connectionPooler.schema` | Schema for pooler auth | `"pgbouncer"` |
| `postgresql.connectionPooler.user` | User for pooler | `"pooler"` |
| `postgresql.connectionPooler.resources` | Resource requests/limits | See values.yaml |

Example:
```yaml
postgresql:
  connectionPooler:
    numberOfInstances: 3
    mode: "transaction"
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
```

### postgresql.env

Environment variables for PostgreSQL container.

For WAL archiving to object storage:

```yaml
postgresql:
  env:
    - name: WAL_S3_BUCKET
      value: "my-backup-bucket"
    - name: AWS_REGION
      value: "us-east-1"
    - name: AWS_ENDPOINT
      value: "https://s3.amazonaws.com"
    - name: AWS_ACCESS_KEY_ID
      valueFrom:
        secretKeyRef:
          name: s3-credentials
          key: access-key-id
    - name: AWS_SECRET_ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: s3-credentials
          key: secret-access-key
    - name: BACKUP_SCHEDULE
      value: "0 2 * * *"  # Daily at 2 AM
```

### postgresql.sidecars

Additional containers in PostgreSQL pods.

Example for postgres-exporter:

```yaml
postgresql:
  sidecars:
    - name: postgres-exporter
      image: quay.io/prometheuscommunity/postgres-exporter:latest
      ports:
        - name: metrics
          containerPort: 9187
          protocol: TCP
      env:
        - name: DATA_SOURCE_NAME
          value: "postgresql://postgres@localhost:5432/postgres?sslmode=disable"
```

## Secrets Configuration

### secret.jwt

JWT authentication secrets.

| Parameter | Description | Required |
|-----------|-------------|----------|
| `secret.jwt.anonKey` | Anonymous API key | Yes |
| `secret.jwt.serviceKey` | Service role key | Yes |
| `secret.jwt.secret` | JWT signing secret | Yes |
| `secret.jwt.exp` | Token expiration (seconds) | No (default: 3600) |

Example:
```yaml
secret:
  jwt:
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    serviceKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    secret: "your-super-secret-jwt-token-with-at-least-32-characters"
    exp: "3600"
```

### secret.dashboard

Studio dashboard credentials.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secret.dashboard.username` | Dashboard username | `"supabase"` |
| `secret.dashboard.password` | Dashboard password | `"this_password_is_insecure_and_should_be_updated"` |

Example:
```yaml
secret:
  dashboard:
    username: "admin"
    password: "change-me-in-production"
```

### secret.smtp

Email/SMTP configuration for Auth service.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secret.smtp.host` | SMTP server | `"mail"` |
| `secret.smtp.port` | SMTP port | `"2500"` |
| `secret.smtp.user` | SMTP username | `"fake_mail_user"` |
| `secret.smtp.pass` | SMTP password | `"fake_mail_password"` |
| `secret.smtp.adminEmail` | Admin email | `"admin@email.com"` |
| `secret.smtp.senderName` | Email sender name | `"Admin"` |

Example:
```yaml
secret:
  smtp:
    host: "smtp.sendgrid.net"
    port: "587"
    user: "apikey"
    pass: "SG.xxxxxxxxxxxx"
    adminEmail: "admin@yourdomain.com"
    senderName: "Your App"
```

### secret.analytics

Analytics service API key.

```yaml
secret:
  analytics:
    apiKey: "your-analytics-api-key"
```

### secret.s3

Object storage credentials for Storage service.

```yaml
secret:
  s3:
    accessKey: "your-access-key"
    secretKey: "your-secret-key"
    region: "us-east-1"
    endpoint: "https://your-storage-endpoint"
```

## Service Configuration

All services follow similar configuration patterns.

### Common Service Parameters

| Parameter | Description |
|-----------|-------------|
| `<service>.enabled` | Enable/disable service |
| `<service>.image.repository` | Container image repository |
| `<service>.image.tag` | Container image tag |
| `<service>.image.pullPolicy` | Image pull policy |
| `<service>.replicaCount` | Number of replicas |
| `<service>.resources` | Resource requests/limits |
| `<service>.service.type` | Service type (ClusterIP/LoadBalancer) |
| `<service>.service.port` | Service port |
| `<service>.environment` | Environment variables |
| `<service>.dbSecretRef` | Database secret reference (auto-configured) |

### auth (GoTrue)

Authentication service configuration.

```yaml
auth:
  enabled: true
  image:
    repository: supabase/gotrue
    tag: v2.99.0
  replicaCount: 2
  environment:
    GOTRUE_SITE_URL: "http://localhost:3000"
    GOTRUE_MAILER_AUTOCONFIRM: "false"
    GOTRUE_DISABLE_SIGNUP: "false"
```

### rest (PostgREST)

REST API service configuration.

```yaml
rest:
  enabled: true
  image:
    repository: postgrest/postgrest
    tag: v12.0.2
  replicaCount: 2
  environment:
    PGRST_DB_SCHEMA: "public,storage,graphql_public"
    PGRST_DB_ANON_ROLE: "anon"
    PGRST_DB_MAX_ROWS: "1000"
```

### realtime

Realtime subscriptions service configuration.

```yaml
realtime:
  enabled: true
  image:
    repository: supabase/realtime
    tag: v2.27.5
  replicaCount: 2
```

### storage

Storage API service configuration.

```yaml
storage:
  enabled: true
  image:
    repository: supabase/storage-api
    tag: v0.43.11
  replicaCount: 2
  environment:
    STORAGE_BACKEND: "s3"  # or "file" for local path
    STORAGE_FILE_SIZE_LIMIT: "52428800"  # 50MB
```

### studio

Studio dashboard configuration.

```yaml
studio:
  enabled: true
  image:
    repository: supabase/studio
    tag: 20231123-64a766a
  replicaCount: 1
  environment:
    STUDIO_PG_META_URL: "http://meta:8080"
```

### kong

API Gateway configuration.

```yaml
kong:
  enabled: true
  image:
    repository: kong
    tag: "3.1"
  replicaCount: 2
  ingress:
    enabled: false
    className: "nginx"
    hosts:
      - host: api.yourdomain.com
        paths:
          - path: /
            pathType: Prefix
    tls: []
```

### meta

Postgres Meta service configuration.

```yaml
meta:
  enabled: true
  image:
    repository: supabase/postgres-meta
    tag: v0.68.0
  replicaCount: 2
```

### analytics

Analytics/Logflare service configuration.

```yaml
analytics:
  enabled: true
  image:
    repository: supabase/logflare
    tag: 1.4.0
  replicaCount: 2
```

### functions

Edge Functions runtime configuration.

```yaml
functions:
  enabled: true
  image:
    repository: supabase/edge-runtime
    tag: v1.22.4
  replicaCount: 2
```

### vector

Log collection service configuration.

```yaml
vector:
  enabled: true
  image:
    repository: timberio/vector
    tag: 0.34.0-alpine
  replicaCount: 1
```

### imgproxy

Image transformation service configuration.

```yaml
imgproxy:
  enabled: true
  image:
    repository: darthsim/imgproxy
    tag: v3.8.0
  replicaCount: 2
```

## Example Configurations

### Minimal Development

```yaml
global:
  clusterName: "dev-db"

secret:
  jwt:
    anonKey: "your-anon-key"
    serviceKey: "your-service-key"
    secret: "your-jwt-secret"
  dashboard:
    password: "dev-password"

postgresql:
  numberOfInstances: 1
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
  volume:
    size: "5Gi"
    storageClass: ""  # Ephemeral
```

### Production High Availability

```yaml
global:
  clusterName: "prod-db"

secret:
  jwt:
    anonKey: "your-production-anon-key"
    serviceKey: "your-production-service-key"
    secret: "your-production-jwt-secret"
  dashboard:
    password: "secure-production-password"
  smtp:
    host: "smtp.sendgrid.net"
    port: "587"
    user: "apikey"
    pass: "your-sendgrid-key"

postgresql:
  numberOfInstances: 3
  resources:
    requests:
      cpu: "2000m"
      memory: "8Gi"
    limits:
      cpu: "4000m"
      memory: "16Gi"
  volume:
    size: "500Gi"
    storageClass: "fast-ssd"
  patroni:
    synchronous_mode: true
  connectionPooler:
    numberOfInstances: 3
  env:
    - name: WAL_S3_BUCKET
      value: "prod-backups"

auth:
  replicaCount: 3
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"

rest:
  replicaCount: 3
  resources:
    requests:
      cpu: "500m"
      memory: "256Mi"

storage:
  replicaCount: 3
  environment:
    STORAGE_BACKEND: "s3"

kong:
  replicaCount: 3
  ingress:
    enabled: true
    className: "nginx"
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

## Advanced Configuration

### Custom PostgreSQL Extensions

Add additional extensions beyond defaults:

```yaml
postgresql:
  # Extensions are pre-installed in Spilo Supabase image
  # Enable them via SQL in init scripts or migrations
```

### Custom Init Scripts

Mount custom SQL scripts:

```yaml
postgresql:
  # Not directly supported in CRD
  # Add custom scripts to Spilo image
```

### Resource Quotas

Set namespace resource limits:

```yaml
# Outside of Helm chart - apply separately
apiVersion: v1
kind: ResourceQuota
metadata:
  name: supabase-quota
  namespace: supabase
spec:
  hard:
    requests.cpu: "20"
    requests.memory: "50Gi"
    persistentvolumeclaims: "10"
```

### Network Policies

Restrict pod-to-pod communication:

```yaml
# Outside of Helm chart - apply separately
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: supabase-network-policy
  namespace: supabase
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

## Validation

### Lint Helm Chart

```bash
helm lint ./helm-charts/supabase-ha --values my-values.yaml
```

### Render Templates

```bash
helm template supabase ./helm-charts/supabase-ha \
  --values my-values.yaml \
  --debug > rendered.yaml
```

### Dry Run

```bash
helm install supabase ./helm-charts/supabase-ha \
  --namespace supabase \
  --create-namespace \
  --values my-values.yaml \
  --dry-run
```

## References

- [Zalando PostgreSQL CRD Reference](https://postgres-operator.readthedocs.io/en/latest/reference/cluster_manifest/)
- [Supabase Self-Hosting Config](https://supabase.com/docs/guides/self-hosting/docker#configuration)
- [PostgreSQL Configuration](https://www.postgresql.org/docs/current/runtime-config.html)
