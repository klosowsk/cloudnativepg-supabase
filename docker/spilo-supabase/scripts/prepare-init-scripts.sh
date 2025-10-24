#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INIT_SCRIPTS_DIR="$PROJECT_ROOT/migrations/init-scripts"
MIGRATIONS_DIR="$PROJECT_ROOT/migrations/migrations"
TEMP_DIR="$PROJECT_ROOT/.tmp"

# Source repositories
SUPABASE_POSTGRES_REPO="https://github.com/supabase/postgres.git"
SUPABASE_POSTGRES_DIR="$TEMP_DIR/supabase-postgres"

# Version to clone - corresponds to supabase/postgres release tag
# This should match the version used in Supabase's docker-compose
SUPABASE_VERSION="${SUPABASE_VERSION:-15.8.1.085}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================"
echo "Supabase Migration Preparation Script"
echo "========================================"
echo -e "${BLUE}Supabase Version: ${SUPABASE_VERSION}${NC}"
echo ""

# Clone or update source repository
clone_repos() {
    echo -e "${BLUE}[1/4] Cloning source repositories...${NC}"

    mkdir -p "$TEMP_DIR"

    if [ -d "$SUPABASE_POSTGRES_DIR" ]; then
        echo -e "${YELLOW}Repository exists, checking out version ${SUPABASE_VERSION}...${NC}"
        cd "$SUPABASE_POSTGRES_DIR"
        git fetch --tags --quiet
        git checkout "$SUPABASE_VERSION" --quiet
        cd "$PROJECT_ROOT"
    else
        echo -e "${YELLOW}Cloning supabase/postgres version ${SUPABASE_VERSION}...${NC}"
        git clone --depth 1 --branch "$SUPABASE_VERSION" --quiet "$SUPABASE_POSTGRES_REPO" "$SUPABASE_POSTGRES_DIR"
    fi

    echo -e "${GREEN}✓ Source repository ready${NC}"
    echo ""
}

# Clean and prepare output directories
prepare_output_dirs() {
    echo -e "${BLUE}[2/4] Preparing output directories...${NC}"

    # Remove existing directories and recreate
    rm -rf "$INIT_SCRIPTS_DIR" "$MIGRATIONS_DIR"
    mkdir -p "$INIT_SCRIPTS_DIR" "$MIGRATIONS_DIR"

    echo -e "${GREEN}✓ Output directories ready${NC}"
    echo ""
}

# Copy init scripts from supabase-postgres
copy_init_scripts() {
    echo -e "${BLUE}[3/4] Copying init scripts and migrations...${NC}"
    echo ""

    local POSTGRES_INIT_DIR="$SUPABASE_POSTGRES_DIR/migrations/db/init-scripts"
    local POSTGRES_MIGRATIONS_DIR="$SUPABASE_POSTGRES_DIR/migrations/db/migrations"
    local init_count=0
    local migration_count=0

    # Copy init scripts
    echo -e "${YELLOW}Copying init scripts from supabase/postgres${NC}"
    if [ -d "$POSTGRES_INIT_DIR" ]; then
        for sql_file in "$POSTGRES_INIT_DIR"/*.sql; do
            if [ -f "$sql_file" ]; then
                local filename=$(basename "$sql_file")
                cp "$sql_file" "$INIT_SCRIPTS_DIR/$filename"
                local lines=$(wc -l < "$INIT_SCRIPTS_DIR/$filename" | tr -d ' ')
                echo -e "  ${GREEN}✓${NC} $filename (${lines} lines)"
                init_count=$((init_count + 1))
            fi
        done
    else
        echo -e "  ${RED}✗${NC} Directory not found: $POSTGRES_INIT_DIR"
        exit 1
    fi

    echo ""

    # Copy migrations
    echo -e "${YELLOW}Copying migrations from supabase/postgres${NC}"
    if [ -d "$POSTGRES_MIGRATIONS_DIR" ]; then
        for sql_file in "$POSTGRES_MIGRATIONS_DIR"/*.sql; do
            if [ -f "$sql_file" ]; then
                local filename=$(basename "$sql_file")
                cp "$sql_file" "$MIGRATIONS_DIR/$filename"
                migration_count=$((migration_count + 1))
            fi
        done
        echo -e "  ${GREEN}✓${NC} ${migration_count} migration files copied"
    else
        echo -e "  ${RED}✗${NC} Directory not found: $POSTGRES_MIGRATIONS_DIR"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}✓ ${init_count} init scripts and ${migration_count} migrations copied successfully${NC}"
    echo ""
}

# Copy custom Zalando-specific files
copy_custom_files() {
    echo -e "${BLUE}[4/5] Copying custom Zalando-specific files...${NC}"
    echo ""

    local CUSTOM_INIT_DIR="$PROJECT_ROOT/migrations/custom-init-scripts"
    local custom_count=0

    # Copy custom files to init-scripts/ (will be executed in Phase 2)
    echo -e "${YELLOW}Copying custom init-scripts (for Phase 2)${NC}"
    for filename in 00-schema.sql 98-webhooks.sql 99-jwt.sql 99-roles.sql; do
        if [ -f "$CUSTOM_INIT_DIR/$filename" ]; then
            cp "$CUSTOM_INIT_DIR/$filename" "$INIT_SCRIPTS_DIR/$filename"
            echo -e "  ${GREEN}✓${NC} $filename → init-scripts/"
            custom_count=$((custom_count + 1))
        else
            echo -e "  ${YELLOW}⚠${NC} $filename not found (skipping)"
        fi
    done

    echo ""

    # Copy custom files to migrations/ (will be executed in Phase 3)
    echo -e "${YELLOW}Copying custom late-stage migrations (for Phase 3)${NC}"
    for filename in 97-_supabase.sql 99-logs.sql 99-pooler.sql 99-realtime.sql; do
        if [ -f "$CUSTOM_INIT_DIR/$filename" ]; then
            cp "$CUSTOM_INIT_DIR/$filename" "$MIGRATIONS_DIR/$filename"
            echo -e "  ${GREEN}✓${NC} $filename → migrations/"
            custom_count=$((custom_count + 1))
        else
            echo -e "  ${YELLOW}⚠${NC} $filename not found (skipping)"
        fi
    done

    echo ""
    echo -e "${GREEN}✓ ${custom_count} custom files copied successfully${NC}"
    echo ""
}

# Cleanup temporary directory
cleanup() {
    echo -e "${BLUE}[5/5] Cleaning up...${NC}"

    echo -e "${YELLOW}Removing temporary directory${NC}"
    rm -rf "$TEMP_DIR"

    echo -e "${GREEN}✓ Cleanup complete${NC}"
    echo ""
}

# Main execution
main() {
    clone_repos
    prepare_output_dirs
    copy_init_scripts
    copy_custom_files
    cleanup

    echo "========================================"
    echo -e "${GREEN}All migrations prepared successfully!${NC}"
    echo "========================================"
    echo ""
    echo "Output locations:"
    echo "  - Init scripts: migrations/init-scripts/"
    echo "  - Migrations:   migrations/migrations/"
    echo ""
    echo "Migration structure (3-phase execution):"
    echo "  Phase 1: zalando-init-scripts/ (pre-init, runs first)"
    echo "  Phase 2: init-scripts/ (core schemas, includes custom 00-*, 98-*, 99-*)"
    echo "  Phase 3: migrations/ (timestamped + custom 97-*, 99-*)"
    echo ""
    echo "Next steps:"
    echo "  1. Review migrations/"
    echo "  2. Rebuild image: ./build.sh"
    echo ""
}

main
