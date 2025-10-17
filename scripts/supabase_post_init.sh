#!/bin/bash
# Supabase-specific initialization script for Spilo/Patroni
#
# This script is called by Spilo's post_init.sh during cluster bootstrap.
# It runs after Patroni has initialized PostgreSQL and Spilo has set up
# its default admin roles and extensions.
#
# The script runs Supabase migrations in order:
# 1. custom-init-scripts: Custom setup (pgbouncer, functions, utility databases)
# 2. init-scripts: Core Supabase schemas (auth, storage, realtime, initial setup)
# 3. migrations: Incremental Supabase migrations (chronological updates)
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

# Phase 1: Run custom init scripts
echo "----------------------------------------"
echo "Phase 1: Custom Initialization Scripts"
echo "----------------------------------------"
CUSTOM_SCRIPTS_DIR="/supabase-migrations/custom-init-scripts"
if [ -d "$CUSTOM_SCRIPTS_DIR" ]; then
    for sql_file in "$CUSTOM_SCRIPTS_DIR"/*.sql; do
        if [ -f "$sql_file" ]; then
            filename=$(basename "$sql_file")
            echo "▶ Running: $filename"
            psql -d "$DATABASE" -v ON_ERROR_STOP=1 -f "$sql_file" 2>&1 | sed 's/^/  /'
            echo "  ✅ Success"
        fi
    done
else
    echo "⚠️  Custom scripts directory not found: $CUSTOM_SCRIPTS_DIR"
fi
echo ""

# Phase 2: Run init scripts (core schemas)
echo "----------------------------------------"
echo "Phase 2: Core Schema Initialization"
echo "----------------------------------------"
INIT_SCRIPTS_DIR="/supabase-migrations/init-scripts"
if [ -d "$INIT_SCRIPTS_DIR" ]; then
    for sql_file in "$INIT_SCRIPTS_DIR"/*.sql; do
        if [ -f "$sql_file" ]; then
            filename=$(basename "$sql_file")
            echo "▶ Running: $filename"
            psql -d "$DATABASE" -v ON_ERROR_STOP=1 -f "$sql_file" 2>&1 | sed 's/^/  /'
            echo "  ✅ Success"
        fi
    done
else
    echo "⚠️  Init scripts directory not found: $INIT_SCRIPTS_DIR"
fi
echo ""

# Phase 3: Run migrations (incremental updates)
echo "----------------------------------------"
echo "Phase 3: Incremental Migrations"
echo "----------------------------------------"
MIGRATIONS_DIR="/supabase-migrations/migrations"
if [ -d "$MIGRATIONS_DIR" ]; then
    # Count migrations
    MIGRATION_COUNT=$(find "$MIGRATIONS_DIR" -name "*.sql" -type f | wc -l)
    echo "Found $MIGRATION_COUNT migrations to apply"
    echo ""

    MIGRATION_NUM=0
    for sql_file in "$MIGRATIONS_DIR"/*.sql; do
        if [ -f "$sql_file" ]; then
            MIGRATION_NUM=$((MIGRATION_NUM + 1))
            filename=$(basename "$sql_file")
            echo "[$MIGRATION_NUM/$MIGRATION_COUNT] Running: $filename"
            psql -d "$DATABASE" -v ON_ERROR_STOP=1 -f "$sql_file" 2>&1 | sed 's/^/  /'
            echo "  ✅ Success"
        fi
    done
else
    echo "⚠️  Migrations directory not found: $MIGRATIONS_DIR"
fi
echo ""

echo "============================================"
echo "✅ Supabase initialization completed!"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Connect Supabase services to this database"
echo "2. Retrieve credentials from Kubernetes secrets"
echo "3. Configure connection string in Supabase environment"
echo ""
