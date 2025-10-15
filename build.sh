#!/usr/bin/env bash
set -euo pipefail

# Build script for CloudNativePG PostgreSQL with Supabase extensions

PG_MAJOR=${PG_MAJOR:-15}
IMAGE_NAME=${IMAGE_NAME:-cnpg-postgres-supabase}
IMAGE_TAG=${IMAGE_TAG:-${PG_MAJOR}}
REGISTRY=${REGISTRY:-""}

# Full image name
if [ -n "$REGISTRY" ]; then
  FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
else
  FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
fi

echo "Building image: $FULL_IMAGE"
echo "PostgreSQL major version: $PG_MAJOR"
echo "Base image: ghcr.io/cloudnative-pg/postgresql:${PG_MAJOR}-bookworm"

# Build the image
docker build \
  --build-arg PG_MAJOR="$PG_MAJOR" \
  -t "$FULL_IMAGE" \
  -f Dockerfile \
  .

echo ""
echo "✅ Build complete: $FULL_IMAGE"
echo ""
echo "To push to registry:"
echo "  docker push $FULL_IMAGE"
echo ""
echo "To use in cluster.yaml:"
echo "  imageName: $FULL_IMAGE"
