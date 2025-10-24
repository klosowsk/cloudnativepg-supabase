# Spilo Supabase

Custom PostgreSQL image based on Zalando Spilo with all Supabase extensions and migrations pre-installed.

## What's Included

- **Base**: Zalando Spilo 3.2-p1 (PostgreSQL 15.8 + Patroni + WAL-G)
- **Supabase**: Complete database schema and extensions (v1.085)
- **Extensions**: pgvector, PostGIS, TimescaleDB, pg_cron, and 40+ more
- **Migrations**: Automatic schema initialization on first boot

## Quick Start

### Using Pre-Built Image

```yaml
# In Helm values.yaml
postgresql:
  dockerImage: klosowsk/spilo-supabase:15.8.1.085-3.2-p1
```

### Building Custom Image

```bash
cd docker/spilo-supabase
./build.sh

# Or manually
docker build -t your-registry/spilo-supabase:custom-tag .
docker push your-registry/spilo-supabase:custom-tag
```

## Key Extensions

| Extension | Purpose |
|-----------|---------|
| **pgsodium** | Encryption library |
| **pg_net** | HTTP client for Edge Functions |
| **supabase_vault** | Secrets management |
| **pg_graphql** | GraphQL API support |
| **pgvector** | Vector similarity search |
| **pg_cron** | Job scheduling |
| **postgis** | Geospatial data |
| **timescaledb** | Time-series data |

Full list: 40+ extensions from Supabase and Pigsty repositories.

## Documentation

- **[Architecture](docs/architecture.md)** - Complete database architecture
- **[Build Guide](docs/build-guide.md)** - Building and customizing the image
- **[Deployment Guide](docs/deployment-guide.md)** - Kubernetes deployment
- **[Migration Structure](docs/migration-structure.md)** - SQL migration details

## Versions

| Component | Version |
|-----------|---------|
| PostgreSQL | 15.8 |
| Spilo | 3.2-p1 |
| Supabase | 1.085 |

## References

- [Zalando Spilo](https://github.com/zalando/spilo)
- [Supabase Postgres](https://github.com/supabase/postgres)
- [Pigsty Extensions](https://pigsty.io/)
