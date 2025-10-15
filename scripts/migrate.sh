#!/bin/sh
set -eu

#######################################
# Supabase database initialization script
# Based on official supabase/postgres migrate.sh
# Runs automatically on first PostgreSQL startup via docker-entrypoint-initdb.d
#
# Env vars:
#   POSTGRES_DB        defaults to postgres
#   POSTGRES_PASSWORD  required
#   JWT_SECRET         required
#   JWT_EXP            defaults to 3600
#######################################

export PGDATABASE="${POSTGRES_DB:-postgres}"
export PGPASSWORD="${POSTGRES_PASSWORD:-}"

# Validate required environment variables
if [ -z "$POSTGRES_PASSWORD" ]; then
  echo "ERROR: POSTGRES_PASSWORD environment variable is required"
  exit 1
fi

if [ -z "$JWT_SECRET" ]; then
  echo "ERROR: JWT_SECRET environment variable is required"
  exit 1
fi

db=$( cd -- "$( dirname -- "$0" )" > /dev/null 2>&1 && pwd )

echo "===================================="
echo "Supabase Migration Runner"
echo "===================================="
echo ""

# Create postgres role as superuser if it doesn't exist
# This matches official Supabase behavior
psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U supabase_admin <<EOSQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'postgres') THEN
    CREATE ROLE postgres SUPERUSER LOGIN PASSWORD '$PGPASSWORD';
    ALTER DATABASE postgres OWNER TO postgres;
  END IF;
END
\$\$;
EOSQL

echo "✅ postgres role ready"
echo ""

# Phase 1: Run init scripts as postgres superuser
echo "Phase 1: Initialization Scripts"
echo "--------------------------------"
for sql in "$db"/init-scripts/*.sql; do
    if [ -f "$sql" ]; then
        filename=$(basename "$sql")
        echo "▶ $filename"
        psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U postgres -f "$sql"
        echo "  ✅ Success"
    fi
done
echo ""

# Set supabase_admin password
psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U postgres -c "ALTER USER supabase_admin WITH PASSWORD '$PGPASSWORD'"

# Phase 2: Run migrations as supabase_admin
echo "Phase 2: Database Migrations"
echo "----------------------------"
for sql in "$db"/migrations/*.sql; do
    if [ -f "$sql" ]; then
        filename=$(basename "$sql")
        echo "▶ $filename"
        psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc -U supabase_admin -f "$sql"
        echo "  ✅ Success"
    fi
done
echo ""

echo "===================================="
echo "✅ All migrations completed!"
echo "===================================="
