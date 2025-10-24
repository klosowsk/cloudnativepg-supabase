# Custom Spilo image with Supabase extensions and migrations
# Extends Zalando's Spilo base image with Pigsty repository for newer extension versions
#
# Build: docker build -f Dockerfile -t ghcr.io/your-org/spilo-supabase:15.8.1.085-3.2-p1 .
# Push:  docker push ghcr.io/your-org/spilo-supabase:15.8.1.085-3.2-p1
#
# Unlike CloudNativePG which ignores /docker-entrypoint-initdb.d/, Spilo/Patroni
# actually executes scripts from the image via bootstrap.post_init callback.

ARG SPILO_VERSION=3.2-p1
ARG PGVERSION=15

FROM ghcr.io/zalando/spilo-${PGVERSION}:${SPILO_VERSION}

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
    patch \
    && rm -rf /var/lib/apt/lists/*

# Add Pigsty APT repository for Supabase extensions
ARG PGVERSION
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://repo.pigsty.io/key | gpg --dearmor -o /etc/apt/keyrings/pigsty.gpg && \
    DISTRO=$(lsb_release -cs) && \
    echo "deb [signed-by=/etc/apt/keyrings/pigsty.gpg] https://repo.pigsty.io/apt/infra generic main" > /etc/apt/sources.list.d/pigsty-io.list && \
    echo "deb [signed-by=/etc/apt/keyrings/pigsty.gpg] https://repo.pigsty.io/apt/pgsql/${DISTRO} ${DISTRO} main" >> /etc/apt/sources.list.d/pigsty-io.list && \
    cat /etc/apt/sources.list.d/pigsty-io.list && \
    apt-get update && \
    # Install libsodium dependency (needed by pgsodium)
    apt-get install -y libsodium23 && \
    # Install extensions from PGDG (already configured in Spilo)
    apt-get install -y \
        postgresql-${PGVERSION}-pgvector \
        postgresql-${PGVERSION}-cron \
        postgresql-${PGVERSION}-wal2json \
        postgresql-${PGVERSION}-postgis-3 \
        postgresql-${PGVERSION}-pgaudit \
        postgresql-${PGVERSION}-plpgsql-check \
        postgresql-${PGVERSION}-pgtap \
        postgresql-${PGVERSION}-http \
        && echo "✓ Installed extensions from PGDG" && \
    # Install Supabase-specific extensions from Pigsty APT repo
    apt-get install -y \
        postgresql-${PGVERSION}-pg-net \
        postgresql-${PGVERSION}-pgsodium \
        postgresql-${PGVERSION}-vault \
        postgresql-${PGVERSION}-pg-graphql \
        postgresql-${PGVERSION}-supautils \
        postgresql-${PGVERSION}-pg-tle \
        postgresql-${PGVERSION}-pgjwt \
        postgresql-${PGVERSION}-pg-jsonschema \
        postgresql-${PGVERSION}-wrappers \
        postgresql-${PGVERSION}-pgmq \
        postgresql-${PGVERSION}-pg-plan-filter \
        postgresql-${PGVERSION}-pg-wait-sampling \
        && echo "✓ Installed Supabase extensions from Pigsty"

# Apply Spilo patches for Supabase security compliance
COPY patches/*.patch /tmp/patches/
RUN cd /scripts && \
    patch -p1 < /tmp/patches/01-spilo-extensions-schema.patch && \
    patch -p1 < /tmp/patches/02-spilo-metric-helpers.patch && \
    patch -p1 < /tmp/patches/03-spilo-search-path-user-functions.patch && \
    patch -p1 < /tmp/patches/04-spilo-search-path-zmon.patch && \
    rm -rf /tmp/patches && \
    echo "✓ Applied Spilo security fixes"

# Create pgsodium getkey script
# This script is required by pgsodium when loaded via shared_preload_libraries
# It generates a 32-byte hex-encoded key for server-level encryption
# For production, consider using AWS KMS, GCP KMS, or another secrets manager
ARG PGVERSION
RUN echo '#!/bin/sh' > /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    echo '# pgsodium getkey script - generates root encryption key' >> /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    echo '# This uses /dev/urandom for key generation' >> /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    echo '# The key is loaded into memory at PostgreSQL startup and never exposed to SQL' >> /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    echo '#' >> /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    echo '# For production environments, consider:' >> /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    echo '# - AWS KMS: aws kms decrypt --key-id <key-id> --ciphertext-blob <encrypted-key>' >> /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    echo '# - GCP KMS: gcloud kms decrypt --key <key> --keyring <keyring> --location <location>' >> /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    echo '# - Kubernetes Secret: kubectl get secret pgsodium-key -o jsonpath='"'"'{.data.key}'"'"' | base64 -d' >> /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    echo '# - Vault: vault kv get -field=key secret/pgsodium' >> /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    echo '#' >> /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    echo '# The script must output exactly one line containing a 64-character hex string' >> /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    echo 'od -vN 32 -An -tx1 /dev/urandom | tr -d " \\n"' >> /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    chmod +x /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    chown postgres:postgres /usr/share/postgresql/${PGVERSION}/extension/pgsodium_getkey && \
    echo "✓ Created pgsodium_getkey script"

# Create directory for Supabase migrations (3-phase structure)
RUN mkdir -p /supabase-migrations/zalando-init-scripts \
             /supabase-migrations/init-scripts \
             /supabase-migrations/migrations

# Copy Supabase migrations using 3-phase structure:
# Phase 1: Zalando pre-init (extensions, admin roles)
# Phase 2: Core schemas (official + custom merged via prepare-init-scripts.sh)
# Phase 3: Migrations (official timestamped + custom late-stage)
#
# Note: init-scripts/ and migrations/ should be prepared by running:
#       ./scripts/prepare-init-scripts.sh
#       This pulls official Supabase files and merges custom Zalando modifications
COPY --chown=postgres:postgres migrations/zalando-init-scripts/*.sql /supabase-migrations/zalando-init-scripts/
COPY --chown=postgres:postgres migrations/init-scripts/*.sql /supabase-migrations/init-scripts/
COPY --chown=postgres:postgres migrations/migrations/*.sql /supabase-migrations/migrations/

# Copy Supabase-specific initialization script
# This script runs the migrations in order during Patroni bootstrap
COPY --chown=postgres:postgres scripts/supabase_post_init.sh /scripts/supabase_post_init.sh
RUN chmod +x /scripts/supabase_post_init.sh

# Hook into Spilo's existing post_init.sh
# Spilo's post_init.sh is called automatically by Patroni during bootstrap
# We append a call to our Supabase initialization script
RUN echo "" >> /scripts/post_init.sh && \
    echo "# Run Supabase-specific initialization" >> /scripts/post_init.sh && \
    echo "echo 'Running Supabase migrations...'" >> /scripts/post_init.sh && \
    echo "/scripts/supabase_post_init.sh \"\$@\"" >> /scripts/post_init.sh && \
    echo "echo 'Supabase migrations completed'" >> /scripts/post_init.sh

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER postgres

LABEL org.opencontainers.image.title="Spilo Supabase"
LABEL org.opencontainers.image.description="Production-ready PostgreSQL with Supabase extensions and migrations for Kubernetes using Zalando Postgres Operator"
LABEL org.opencontainers.image.source="https://github.com/klosowsk/spilo-supabase"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.vendor="klosowsk"
