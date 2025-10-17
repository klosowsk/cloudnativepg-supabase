#!/usr/bin/env bash
set -euo pipefail

# Build script for Spilo PostgreSQL with Supabase extensions

SPILO_VERSION=${SPILO_VERSION:-4.0-p3}
PG_VERSION=${PG_VERSION:-17}
IMAGE_NAME=${IMAGE_NAME:-spilo-supabase}
IMAGE_TAG=${IMAGE_TAG:-${PG_VERSION}-latest}
REGISTRY=${REGISTRY:-""}

# Full image name
if [ -n "$REGISTRY" ]; then
  FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
else
  FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
fi

echo "Building image: $FULL_IMAGE"
echo "PostgreSQL version: $PG_VERSION"
echo "Spilo version: $SPILO_VERSION"
echo "Base image: ghcr.io/zalando/spilo-${PG_VERSION}:${SPILO_VERSION}"

# Build the image
docker build \
  --build-arg PGVERSION="$PG_VERSION" \
  --build-arg SPILO_VERSION="$SPILO_VERSION" \
  -t "$FULL_IMAGE" \
  -f Dockerfile \
  .

echo ""
echo "✅ Build complete: $FULL_IMAGE"
echo ""
echo "To test the image:"
echo "  docker run --rm $FULL_IMAGE bash -c 'postgres --version'"
echo "  docker run --rm $FULL_IMAGE bash -c 'find /supabase-migrations -type f | wc -l'"
echo ""
echo "To push to registry:"
echo "  docker push $FULL_IMAGE"
echo ""
echo "To use in Zalando PostgreSQL manifest:"
echo "  dockerImage: $FULL_IMAGE"
echo ""
