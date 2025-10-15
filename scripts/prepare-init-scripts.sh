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

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================"
echo "Supabase Migration Preparation Script"
echo "========================================"
echo ""

# Clone or update source repository
clone_repos() {
    echo -e "${BLUE}[1/4] Cloning source repositories...${NC}"

    mkdir -p "$TEMP_DIR"

    if [ -d "$SUPABASE_POSTGRES_DIR" ]; then
        echo -e "${YELLOW}Repository exists, updating...${NC}"
        cd "$SUPABASE_POSTGRES_DIR"
        git pull --quiet
        cd "$PROJECT_ROOT"
    else
        echo -e "${YELLOW}Cloning supabase/postgres...${NC}"
        git clone --depth 1 --quiet "$SUPABASE_POSTGRES_REPO" "$SUPABASE_POSTGRES_DIR"
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

# Cleanup temporary directory
cleanup() {
    echo -e "${BLUE}[4/4] Cleaning up...${NC}"

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
    cleanup

    echo "========================================"
    echo -e "${GREEN}All migrations prepared successfully!${NC}"
    echo "========================================"
    echo ""
    echo "Output locations:"
    echo "  - Init scripts: migrations/init-scripts/"
    echo "  - Migrations:   migrations/migrations/"
    echo ""
    echo "Next steps:"
    echo "  1. Review migrations/"
    echo "  2. Rebuild image: ./build.sh"
    echo ""
}

main
