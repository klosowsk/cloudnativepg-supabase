#!/bin/bash
set -e

# Script to compare schemas between official Supabase and our custom image
# Usage: ./scripts/compare-schemas.sh

OFFICIAL_CONTAINER="${OFFICIAL_CONTAINER:-supabase-db}"
CUSTOM_CONTAINER="${CUSTOM_CONTAINER:-spilo-test}"

echo "Comparing schemas between:"
echo "  Official: $OFFICIAL_CONTAINER"
echo "  Custom:   $CUSTOM_CONTAINER"
echo ""

# Function to dump schema from a container
dump_schema() {
    local container=$1
    local output_file=$2
    local db_name="${3:-postgres}"
    local user="${4:-postgres}"

    echo "Dumping schema from $container..."
    docker exec "$container" pg_dump -U "$user" -d "$db_name" \
        --schema-only \
        --no-owner \
        --no-privileges \
        --no-tablespaces \
        --no-security-labels \
        --no-comments \
        > "$output_file" 2>/dev/null || {
            echo "Warning: pg_dump failed for $container, trying psql fallback..."
            docker exec "$container" psql -U "$user" -d "$db_name" -c "\d" > "$output_file" 2>/dev/null
        }
}

# Function to list all schemas, tables, and roles
dump_objects() {
    local container=$1
    local output_file=$2
    local user="${3:-postgres}"

    echo "Listing database objects from $container..."
    docker exec "$container" psql -U "$user" -d postgres <<'SQL' > "$output_file" 2>/dev/null || true
\echo '=== SCHEMAS ==='
SELECT schema_name FROM information_schema.schemata ORDER BY schema_name;

\echo ''
\echo '=== TABLES ==='
SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema') ORDER BY schemaname, tablename;

\echo ''
\echo '=== ROLES ==='
SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin FROM pg_roles WHERE rolname NOT LIKE 'pg_%' ORDER BY rolname;

\echo ''
\echo '=== EXTENSIONS ==='
SELECT extname, extversion FROM pg_extension ORDER BY extname;

\echo ''
\echo '=== DATABASES ==='
SELECT datname FROM pg_database WHERE datname NOT IN ('template0', 'template1') ORDER BY datname;
SQL
}

# Create output directory
mkdir -p /tmp/schema-comparison

# Dump from official container
echo "Extracting from official Supabase container..."
dump_objects "$OFFICIAL_CONTAINER" "/tmp/schema-comparison/official-objects.txt" "postgres"
dump_schema "$OFFICIAL_CONTAINER" "/tmp/schema-comparison/official-schema.sql" "postgres" "postgres"

# Check if custom container is running, if not skip
if docker ps --format '{{.Names}}' | grep -q "^${CUSTOM_CONTAINER}$"; then
    echo "Extracting from custom container..."
    dump_objects "$CUSTOM_CONTAINER" "/tmp/schema-comparison/custom-objects.txt" "postgres"
    dump_schema "$CUSTOM_CONTAINER" "/tmp/schema-comparison/custom-schema.sql" "postgres" "postgres"

    echo ""
    echo "=== COMPARISON ==="
    echo ""
    echo "Object differences:"
    diff -u /tmp/schema-comparison/official-objects.txt /tmp/schema-comparison/custom-objects.txt || true

    echo ""
    echo "Schema differences:"
    diff -u /tmp/schema-comparison/official-schema.sql /tmp/schema-comparison/custom-schema.sql | head -100 || true
else
    echo ""
    echo "Custom container '$CUSTOM_CONTAINER' not running. Skipping comparison."
    echo "To run custom container:"
    echo "  docker run --name spilo-test -e PGPASSWORD=postgres spilo-supabase:15.8.1.085-3.2-p1"
fi

echo ""
echo "Schema dumps saved to /tmp/schema-comparison/"
echo "  - official-objects.txt"
echo "  - official-schema.sql"
if docker ps --format '{{.Names}}' | grep -q "^${CUSTOM_CONTAINER}$"; then
    echo "  - custom-objects.txt"
    echo "  - custom-schema.sql"
fi
