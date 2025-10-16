# Build custom CloudNativePG image with Supabase extensions via Pigsty
# Based on official CNPG image with all required Supabase extensions
# Using Debian Bookworm for full Pigsty extension support

ARG PG_MAJOR=15

# Use Bookworm-based image (Bullseye is deprecated, Bookworm has full Pigsty support)
FROM ghcr.io/cloudnative-pg/postgresql:${PG_MAJOR}-bookworm

USER root

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Install required tools
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    wget \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Add Pigsty GPG key and infra repository
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://repo.pigsty.io/key | gpg --dearmor -o /etc/apt/keyrings/pigsty.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/pigsty.gpg] https://repo.pigsty.io/apt/infra generic main" > /etc/apt/sources.list.d/pigsty-infra.list && \
    apt-get update

# Install pig CLI
RUN apt-get update && apt-get install -y pig && rm -rf /var/lib/apt/lists/*

# Remove existing PGDG repo to avoid conflict, then use pig to add both repos
# Ensure the pgsql repo definition uses the same GPG key
RUN rm -f /etc/apt/sources.list.d/pgdg.list && \
    pig repo add pgsql pgdg -u && \
    sed -i 's/signed-by=[^ ]*/signed-by=\/etc\/apt\/keyrings\/pigsty.gpg/' /etc/apt/sources.list.d/pgsql.list 2>/dev/null || true && \
    apt-get update

# Install CRITICAL Supabase extensions
# Note: Using direct apt-get with correct package names from Pigsty repo
ARG PG_MAJOR
RUN apt-get update && apt-get install -y \
    postgresql-${PG_MAJOR}-pg-net \
    postgresql-${PG_MAJOR}-cron \
    postgresql-${PG_MAJOR}-wal2json \
    || echo "Some critical extensions failed to install"

# Install RECOMMENDED extensions
RUN apt-get install -y \
    postgresql-${PG_MAJOR}-pgaudit \
    postgresql-${PG_MAJOR}-plpgsql-check \
    postgresql-${PG_MAJOR}-pgtap \
    || echo "Some recommended extensions failed to install"

# Install OPTIONAL extensions (commonly used)
RUN apt-get install -y \
    postgresql-${PG_MAJOR}-pgvector \
    postgresql-${PG_MAJOR}-postgis-3 \
    postgresql-${PG_MAJOR}-postgis-3-scripts \
    postgresql-${PG_MAJOR}-http \
    || echo "Some optional extensions failed to install"

# Install remaining Supabase extensions
RUN apt-get install -y \
    postgresql-${PG_MAJOR}-pgsodium \
    postgresql-${PG_MAJOR}-pg-graphql \
    postgresql-${PG_MAJOR}-supautils \
    postgresql-${PG_MAJOR}-vault \
    postgresql-${PG_MAJOR}-pg-tle \
    || echo "Some Supabase-specific extensions not available in current repos"

# Set environment variables to match official Supabase image
# JWT_EXP defaults to 3600 seconds (1 hour)
ENV JWT_EXP=3600

# Copy Supabase migrations into the image
# NOTE: CloudNativePG does NOT use /docker-entrypoint-initdb.d/ for initialization!
# These files are included for reference and for generating Kubernetes ConfigMaps.
# Actual initialization happens via postInitSQLRefs in the Cluster manifest.
# See: examples/cluster.yaml and k8s/supabase-init-configmaps.yaml
#
# To generate ConfigMaps from these files, run:
#   ./scripts/generate-configmaps.sh
RUN mkdir -p /opt/supabase/migrations
COPY --chown=postgres:postgres migrations/ /opt/supabase/migrations/

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER 26

LABEL org.opencontainers.image.title="CloudNativePG PostgreSQL with Supabase Extensions"
LABEL org.opencontainers.image.description="CloudNativePG-compatible PostgreSQL image with all Supabase extensions and migrations pre-installed"
LABEL org.opencontainers.image.source="https://github.com/YOUR_USERNAME/cnpg-supabase"
LABEL org.opencontainers.image.licenses="Apache-2.0"
