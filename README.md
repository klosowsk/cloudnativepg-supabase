# Spilo Supabase

**Supabase-ready PostgreSQL for Kubernetes with high availability.**

A custom [Spilo](https://github.com/zalando/spilo) image with all Supabase extensions and migrations pre-installed. Deploy with [Zalando Postgres Operator](https://github.com/zalando/postgres-operator) for production-ready HA PostgreSQL clusters.

> Schemas, extensions, and migrations are sourced from the [official Supabase repositories](https://github.com/supabase/postgres).

## What You Get

### Supabase Schemas
- `auth` - User authentication
- `storage` - File storage
- `realtime` - WebSocket subscriptions
- `extensions` - PostgreSQL extensions
- `supabase_functions` - Edge Functions
- `graphql_public` - GraphQL API
- All internal Supabase schemas

### Supabase Extensions
- `pg_net` - Async HTTP (Edge Functions)
- `pgsodium` - Encryption
- `supabase_vault` - Secrets management
- `pg_graphql` - GraphQL API
- `supautils` - Supabase utilities
- `pgvector` - Vector similarity (AI/embeddings)
- `pg_tle` - Trusted Language Extensions
- `pg_cron` - Job scheduling
- `wal2json` - Realtime replication
- `postgis` - Geospatial data
- And more...

### Supabase Roles
All standard Supabase roles are created automatically (from official Supabase repos):
- `supabase_admin`, `authenticator`, `service_role`, `anon`, `authenticated`
- Service-specific admin roles for auth, storage, and functions
- Replication and read-only users

## Quick Start

### 1. Install Zalando Postgres Operator

```bash
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm install postgres-operator postgres-operator-charts/postgres-operator \
  --namespace postgres-operator --create-namespace
```

### 2. Use Pre-Built Image

```bash
docker pull klosowsk/spilo-supabase:17-latest
```

Or build your own:
```bash
./build.sh
```

See [documentation/build-guide.md](documentation/build-guide.md) for build details.

### 3. Deploy Database

Choose a deployment template and customize for your environment:

| Template | Nodes | Use Case |
|----------|-------|----------|
| [single.yaml](manifests/supabase-postgres-zalando-single.yaml) | 1 | Development, Testing |
| [duo.yaml](manifests/supabase-postgres-zalando-duo.yaml) | 2 | Staging |
| [trio.yaml](manifests/supabase-postgres-zalando-trio.yaml) | 3 | Production |

```bash
# Edit the manifest to customize for your environment
# Then apply:
kubectl apply -f manifests/supabase-postgres-zalando-trio.yaml
```

### 4. Get Credentials

```bash
# Retrieve the authenticator password
kubectl get secret authenticator.supabase-db.credentials.postgresql.acid.zalan.do \
  -n supabase -o jsonpath='{.data.password}' | base64 -d
```

### 5. Connect Supabase Services

Point your Supabase services to the connection pooler:

```yaml
POSTGRES_HOST: supabase-db-pooler.supabase.svc.cluster.local
POSTGRES_PORT: 5432
POSTGRES_DB: postgres
POSTGRES_USER: authenticator
POSTGRES_PASSWORD: <from-secret-above>
```

## Verification

```bash
# Check cluster status
kubectl get postgresql -n supabase

# View logs
kubectl logs supabase-db-0 -n supabase | grep "Supabase"

# Connect and verify
kubectl exec -it supabase-db-0 -n supabase -- psql -U postgres
\dn          -- List schemas
\dx          -- List extensions
```

## Documentation

- [Architecture Overview](documentation/architecture.md) - What's included
- [Build Guide](documentation/build-guide.md) - How to build the image
- [Deployment Guide](documentation/deployment-guide.md) - Deployment and operations

For Zalando Postgres Operator details, see the [official documentation](https://postgres-operator.readthedocs.io/).

## License

Apache License 2.0

## Acknowledgments

Built with:
- [Zalando Postgres Operator](https://github.com/zalando/postgres-operator) - Kubernetes PostgreSQL operator
- [Spilo](https://github.com/zalando/spilo) - PostgreSQL HA container image
- [Supabase](https://github.com/supabase/postgres) - Open source Firebase alternative
- [Pigsty](https://pigsty.io/) - PostgreSQL extension repository
