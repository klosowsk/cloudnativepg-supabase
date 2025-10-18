#!/bin/bash
# Supabase-specific initialization script for Spilo/Patroni
#
# This script is called by Spilo's post_init.sh during cluster bootstrap.
# It runs after Patroni has initialized PostgreSQL and Spilo has set up
# its default admin roles and extensions.
#
# The script runs Supabase migrations in 3 phases (matching official Supabase structure):
# Phase 1: zalando-init-scripts - Zalando pre-init (extensions, admin roles)
# Phase 2: init-scripts - Core schemas (official + custom 00-*, 98-*, 99-*)
# Phase 3: migrations - Incremental migrations (official timestamped + custom 97-*, 99-*)
#
# Arguments (passed from post_init.sh):
#   $1: HUMAN_ROLE - Admin role name (e.g., "admin")
#   $2: DATABASE - Database name (defaults to "postgres")

set -e

# Arguments from post_init.sh
HUMAN_ROLE=${1:-admin}
DATABASE=${2:-postgres}

echo "============================================"
echo "Supabase Initialization Script"
echo "============================================"
echo "Human role: $HUMAN_ROLE"
echo "Database: $DATABASE"
echo ""

# Check if we're on the primary (skip on replicas)
IS_REPLICA=$(psql -tAXc 'SELECT pg_is_in_recovery()' -d "$DATABASE" 2>/dev/null || echo "t")
if [ "$IS_REPLICA" = "t" ]; then
    echo "⏭️  Running on replica, skipping Supabase initialization"
    exit 0
fi

echo "✅ Running on primary, proceeding with initialization"
echo ""

# Check if Supabase is already initialized
# We check for the 'auth' schema as a marker
SUPABASE_INITIALIZED=$(psql -d "$DATABASE" -tAXc \
    "SELECT COUNT(*) FROM pg_catalog.pg_namespace WHERE nspname = 'auth'" 2>/dev/null || echo "0")

if [ "$SUPABASE_INITIALIZED" != "0" ]; then
    echo "⏭️  Supabase already initialized (auth schema exists), skipping migrations"
    exit 0
fi

echo "🚀 Supabase not initialized, running migrations..."
echo ""

# Set psql options for clean execution
export PGOPTIONS="-c synchronous_commit=local -c search_path=pg_catalog"

# Phase 1: Zalando Pre-Initialization
echo "========================================"
echo "Phase 1: Zalando Pre-Initialization"
echo "========================================"
echo "Purpose: Create extensions and admin roles BEFORE official scripts"
echo ""
ZALANDO_SCRIPTS_DIR="/supabase-migrations/zalando-init-scripts"
if [ -d "$ZALANDO_SCRIPTS_DIR" ]; then
    for sql_file in "$ZALANDO_SCRIPTS_DIR"/*.sql; do
        if [ -f "$sql_file" ]; then
            filename=$(basename "$sql_file")
            echo "▶ Running: $filename"
            psql -d "$DATABASE" -v ON_ERROR_STOP=1 -f "$sql_file" 2>&1 | sed 's/^/  /'
            echo "  ✅ Success"
        fi
    done
else
    echo "⚠️  Zalando scripts directory not found: $ZALANDO_SCRIPTS_DIR"
fi
echo ""

# Phase 2: Core Schema Initialization
echo "========================================"
echo "Phase 2: Core Schema Initialization"
echo "========================================"
echo "Purpose: Official Supabase schemas + custom Zalando modifications"
echo "Running as: supabase_admin (ensures proper schema ownership)"
echo ""
INIT_SCRIPTS_DIR="/supabase-migrations/init-scripts"
if [ -d "$INIT_SCRIPTS_DIR" ]; then
    for sql_file in "$INIT_SCRIPTS_DIR"/*.sql; do
        if [ -f "$sql_file" ]; then
            filename=$(basename "$sql_file")
            echo "▶ Running: $filename"
            psql -U supabase_admin -d "$DATABASE" -v ON_ERROR_STOP=1 -f "$sql_file" 2>&1 | sed 's/^/  /'
            echo "  ✅ Success"
        fi
    done
else
    echo "⚠️  Init scripts directory not found: $INIT_SCRIPTS_DIR"
fi
echo ""

# Phase 3: Incremental Migrations
echo "========================================"
echo "Phase 3: Incremental Migrations"
echo "========================================"
echo "Purpose: Official timestamped migrations + custom late-stage setup"
echo "Running as: supabase_admin (application superuser)"
echo ""
MIGRATIONS_DIR="/supabase-migrations/migrations"
if [ -d "$MIGRATIONS_DIR" ]; then
    # Count migrations (excluding demote-postgres which is incompatible with Patroni)
    MIGRATION_COUNT=$(find "$MIGRATIONS_DIR" -name "*.sql" -type f ! -name "*demote-postgres*" | wc -l)
    echo "Found $MIGRATION_COUNT migrations to apply (skipping demote-postgres for Patroni compatibility)"
    echo ""

    MIGRATION_NUM=0
    for sql_file in "$MIGRATIONS_DIR"/*.sql; do
        if [ -f "$sql_file" ]; then
            filename=$(basename "$sql_file")

            # Skip demote-postgres migration - incompatible with Patroni which needs postgres to remain superuser
            if [[ "$filename" == *"demote-postgres"* ]]; then
                echo "⏭️  Skipping: $filename (Patroni requires postgres to remain superuser)"
                continue
            fi

            MIGRATION_NUM=$((MIGRATION_NUM + 1))
            echo "[$MIGRATION_NUM/$MIGRATION_COUNT] Running: $filename"
            psql -U supabase_admin -d "$DATABASE" -v ON_ERROR_STOP=1 -f "$sql_file" 2>&1 | sed 's/^/  /'
            echo "  ✅ Success"
        fi
    done
else
    echo "⚠️  Migrations directory not found: $MIGRATIONS_DIR"
fi
echo ""

# Transfer ownership of Spilo-created extension schemas to supabase_admin
# Note: This is optional since both postgres and supabase_admin are superusers.
# Uncomment if you need exact schema ownership parity with official Supabase.
#
# echo "▶ Transferring extension schema ownership to supabase_admin"
# for schema in graphql graphql_public realtime vault; do
#     psql -U supabase_admin -d "$DATABASE" -tAXc "ALTER SCHEMA $schema OWNER TO supabase_admin;" 2>/dev/null || true
# done
# echo "  ✅ Schema ownership transferred"
# echo ""

echo "============================================"
echo "✅ Supabase initialization completed!"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Connect Supabase services to this database"
echo "2. Retrieve credentials from Kubernetes secrets"
echo "3. Configure connection string in Supabase environment"
echo ""
