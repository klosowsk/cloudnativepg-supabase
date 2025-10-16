# Build Guide

## Quick Build

Build the Spilo Supabase image locally:

```bash
git clone https://github.com/klosowsk/spilo-supabase.git
cd spilo-supabase
./build.sh
```

This creates `spilo-supabase:17-latest`.

## Test the Image

```bash
# Verify PostgreSQL version
docker run --rm spilo-supabase:17-latest bash -c "postgres --version"

# Check extensions installed
docker run --rm spilo-supabase:17-latest bash -c "dpkg -l | grep postgresql-17-pg-net"

# Verify migration files
docker run --rm spilo-supabase:17-latest bash -c "find /supabase-migrations -type f -name '*.sql' | wc -l"
```

## Customize Build

### Change PostgreSQL Version

```bash
# Build for PostgreSQL 16
PG_VERSION=16 SPILO_VERSION=4.0-p3 ./build.sh
```

### Use Custom Registry

```bash
# Build and tag for your registry
REGISTRY=myregistry.com IMAGE_NAME=my-spilo-supabase ./build.sh

# Push to registry
docker push myregistry.com/my-spilo-supabase:17-latest
```

## Multi-Architecture Build

For production deployments across different CPU architectures:

```bash
# Setup buildx (first time only)
docker buildx create --name multiarch --use

# Build for AMD64 and ARM64
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg PGVERSION=17 \
  --build-arg SPILO_VERSION=4.0-p3 \
  -t myregistry.com/spilo-supabase:17-latest \
  --push \
  .
```

## Update Migrations

To fetch the latest Supabase migrations from upstream:

```bash
./scripts/prepare-init-scripts.sh
./build.sh
```

This updates migrations from the [official Supabase repos](https://github.com/supabase/postgres).

## GitHub Actions

The repository includes automated builds via GitHub Actions:

### On Tag Push

```bash
# Create a release tag
git tag spilo-v17-4.0-p3
git push origin spilo-v17-4.0-p3
```

This automatically builds and pushes to Docker Hub:
- `klosowsk/spilo-supabase:17-4.0-p3`
- `klosowsk/spilo-supabase:17-latest`
- `klosowsk/spilo-supabase:latest`

## What's In The Image

- **Base**: Zalando Spilo 17:4.0-p3 (PostgreSQL + Patroni + WAL-G)
- **Extensions**: All Supabase extensions from Pigsty repository
- **Migrations**: 55+ SQL files from official Supabase repos
- **Bootstrap script**: Auto-runs migrations on first start

## Troubleshooting

**Build fails on extension installation**

Verify Pigsty repository is accessible:
```bash
docker run --rm debian:bookworm bash -c "curl -fsSL https://repo.pigsty.io/key"
```

**Image too large**

The image is ~900MB due to PostgreSQL + all extensions. This is normal for a complete Supabase stack.

## For More Details

- Dockerfile: [Dockerfile](../Dockerfile)
- Base Spilo image: https://github.com/zalando/spilo
- Pigsty repository: https://pigsty.io/
