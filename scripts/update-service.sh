#!/bin/bash
# update-service.sh - BorgStack Service Update Script
#
# Usage:
#   ./scripts/update-service.sh SERVICE_NAME [NEW_VERSION]
#
# Examples:
#   ./scripts/update-service.sh n8n 1.113.0
#   ./scripts/update-service.sh postgresql 18.1
#   ./scripts/update-service.sh lowcoder latest
#
# Description:
#   Safely updates a single BorgStack service with automatic backup,
#   health checks, and rollback capability.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOG_FILE="/var/log/borgstack-updates.log"
BACKUP_DIR="backups/pre-update"
COMPOSE_FILE="docker-compose.yml"
COMPOSE_BACKUP="docker-compose.yml.backup"

# Initialize function (called only when actually running update)
init_directories() {
    # Ensure log directory exists
    if [ ! -d "$(dirname "$LOG_FILE")" ]; then
        sudo mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || {
            LOG_FILE="./borgstack-updates.log"
            echo "⚠️  Cannot create /var/log directory, using ./borgstack-updates.log instead"
        }
    fi

    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"
}

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    case "$level" in
        ERROR)
            echo -e "${RED}❌ $message${NC}" >&2
            ;;
        SUCCESS)
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        WARNING)
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        INFO)
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Get changelog URL for service
get_changelog_url() {
    local service="$1"

    case "$service" in
        n8n)
            echo "https://github.com/n8n-io/n8n/releases"
            ;;
        chatwoot)
            echo "https://github.com/chatwoot/chatwoot/releases"
            ;;
        directus)
            echo "https://github.com/directus/directus/releases"
            ;;
        evolution)
            echo "https://github.com/EvolutionAPI/evolution-api/releases"
            ;;
        postgresql)
            echo "https://www.postgresql.org/docs/release/"
            ;;
        mongodb)
            echo "https://www.mongodb.com/docs/manual/release-notes/"
            ;;
        redis)
            echo "https://github.com/redis/redis/releases"
            ;;
        caddy)
            echo "https://github.com/caddyserver/caddy/releases"
            ;;
        seaweedfs)
            echo "https://github.com/seaweedfs/seaweedfs/releases"
            ;;
        lowcoder*)
            echo "https://github.com/lowcoder-org/lowcoder/releases"
            ;;
        duplicati)
            echo "https://github.com/duplicati/duplicati/releases"
            ;;
        fileflows)
            echo "https://github.com/revenz/FileFlows/releases"
            ;;
        *)
            echo "Unknown service changelog"
            ;;
    esac
}

# Get related services for multi-container services
get_related_services() {
    local service="$1"

    # Handle Lowcoder multi-container service
    if [[ "$service" =~ ^lowcoder ]]; then
        echo "lowcoder-api-service lowcoder-node-service lowcoder-frontend"
    else
        echo "$service"
    fi
}

# Get current version of service
get_current_version() {
    local service="$1"
    docker compose images "$service" 2>/dev/null | grep "$service" | awk '{print $2}' | head -1
}

# Validate service exists in docker-compose.yml
validate_service() {
    local service="$1"

    if ! docker compose config --services | grep -q "^${service}$"; then
        log ERROR "Service '$service' not found in docker-compose.yml"
        log INFO "Available services:"
        docker compose config --services | sed 's/^/  - /'
        exit 1
    fi
}

# Create backup of service data
backup_service() {
    local service="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/${service}_${timestamp}"

    log INFO "Creating backup of $service..."

    # Backup docker-compose.yml
    cp "$COMPOSE_FILE" "${COMPOSE_BACKUP}_${timestamp}"
    log SUCCESS "Backed up docker-compose.yml to ${COMPOSE_BACKUP}_${timestamp}"

    # Service-specific backups
    case "$service" in
        n8n|chatwoot|directus|evolution)
            # PostgreSQL-backed services
            local db_name="${service}_db"
            if docker compose exec -T postgresql psql -U postgres -lqt | cut -d \| -f 1 | grep -qw "$db_name"; then
                docker compose exec -T postgresql pg_dump -U postgres "$db_name" | gzip > "${backup_file}_db.sql.gz"
                log SUCCESS "Backed up PostgreSQL database: ${db_name}"
            fi
            ;;
        postgresql)
            # Backup all PostgreSQL databases
            docker compose exec -T postgresql pg_dumpall -U postgres -c | gzip > "${backup_file}_all.sql.gz"
            log SUCCESS "Backed up all PostgreSQL databases"
            ;;
        mongodb)
            # Backup MongoDB
            docker compose exec -T mongodb mongodump --archive --gzip > "${backup_file}.archive.gz" 2>/dev/null || true
            log SUCCESS "Backed up MongoDB databases"
            ;;
        redis)
            # Backup Redis
            docker compose exec redis redis-cli BGSAVE >/dev/null 2>&1 || true
            sleep 2
            log SUCCESS "Triggered Redis backup"
            ;;
        lowcoder*)
            # Lowcoder uses MongoDB
            docker compose exec -T mongodb mongodump --archive --gzip > "${backup_file}_mongodb.archive.gz" 2>/dev/null || true
            log SUCCESS "Backed up Lowcoder MongoDB data"
            ;;
    esac

    log SUCCESS "Backup completed: ${backup_file}*"
}

# Update docker-compose.yml with new version
update_compose_file() {
    local service="$1"
    local new_version="$2"

    log INFO "Updating docker-compose.yml for $service..."

    # Get current image line
    local current_line=$(grep -A5 "^  ${service}:" "$COMPOSE_FILE" | grep "image:" | head -1)

    if [ -z "$current_line" ]; then
        log ERROR "Could not find image definition for service $service"
        return 1
    fi

    # Extract image name without version
    local image_base=$(echo "$current_line" | sed -E 's/.*image: *([^:]+):.*$/\1/')

    # Create new image line
    local new_line="    image: ${image_base}:${new_version}"

    # Update file
    sed -i "s|.*image: ${image_base}:.*|${new_line}|" "$COMPOSE_FILE"

    log SUCCESS "Updated $service to version $new_version in docker-compose.yml"
}

# Check service health
check_health() {
    local service="$1"
    local max_retries=5
    local retry_interval=10
    local retry=0

    log INFO "Checking health of $service..."

    while [ $retry -lt $max_retries ]; do
        local status=$(docker compose ps "$service" --format json 2>/dev/null | jq -r '.[0].Health // "unknown"')

        if [ "$status" = "healthy" ] || [ "$status" = "unknown" ]; then
            # Also check if container is running
            local state=$(docker compose ps "$service" --format json 2>/dev/null | jq -r '.[0].State')

            if [ "$state" = "running" ]; then
                log SUCCESS "$service is healthy and running"
                return 0
            fi
        fi

        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            log WARNING "Health check attempt $retry/$max_retries failed, retrying in ${retry_interval}s..."
            sleep $retry_interval
        fi
    done

    log ERROR "Health check failed after $max_retries attempts"
    return 1
}

# Monitor logs for errors
check_logs_for_errors() {
    local service="$1"
    local duration=10

    log INFO "Checking logs for errors..."

    local error_count=$(docker compose logs --since "${duration}s" "$service" 2>&1 | \
        grep -iE "error|fatal|panic" | \
        grep -viE "error.log|ErrorLog|error_level|error_reporting" | \
        wc -l)

    if [ "$error_count" -gt 0 ]; then
        log WARNING "Found $error_count error-like messages in logs"
        log INFO "Recent error messages:"
        docker compose logs --since "${duration}s" "$service" 2>&1 | \
            grep -iE "error|fatal|panic" | \
            grep -viE "error.log|ErrorLog|error_level|error_reporting" | \
            tail -5
        return 1
    fi

    log SUCCESS "No critical errors found in logs"
    return 0
}

# Rollback to previous version
rollback() {
    local service="$1"
    local backup_file="$2"

    log WARNING "Starting rollback for $service..."

    # Restore docker-compose.yml
    if [ -f "$backup_file" ]; then
        cp "$backup_file" "$COMPOSE_FILE"
        log SUCCESS "Restored docker-compose.yml from backup"
    else
        log ERROR "Backup file not found: $backup_file"
        return 1
    fi

    # Stop service
    log INFO "Stopping $service..."
    docker compose stop "$service" >/dev/null 2>&1

    # Pull old image
    log INFO "Pulling previous image version..."
    docker compose pull "$service" >/dev/null 2>&1

    # Recreate container
    log INFO "Recreating container with previous version..."
    docker compose up -d --force-recreate "$service" >/dev/null 2>&1

    # Wait for startup
    sleep 10

    # Verify health
    if check_health "$service"; then
        log SUCCESS "Rollback completed successfully"
        return 0
    else
        log ERROR "Rollback completed but service is not healthy"
        return 1
    fi
}

# Main update function
update_service() {
    local service="$1"
    local new_version="$2"

    log INFO "========================================="
    log INFO "BorgStack Service Update"
    log INFO "Service: $service"
    log INFO "Target Version: $new_version"
    log INFO "========================================="

    # Step 1: Validate service
    validate_service "$service"

    # Step 2: Get current version
    local current_version=$(get_current_version "$service")
    log INFO "Current version: $current_version"

    if [ "$current_version" = "$new_version" ]; then
        log WARNING "Service is already at version $new_version"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log INFO "Update cancelled"
            exit 0
        fi
    fi

    # Step 3: Display changelog
    local changelog_url=$(get_changelog_url "$service")
    log INFO "Changelog: $changelog_url"
    log INFO "Please review the changelog before proceeding"

    # Step 4: Confirmation
    echo
    read -p "Proceed with update? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log INFO "Update cancelled by user"
        exit 0
    fi

    # Step 5: Create backup
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_compose="${COMPOSE_BACKUP}_${timestamp}"
    backup_service "$service"

    # Get all related services (for multi-container services)
    local services=$(get_related_services "$service")
    log INFO "Services to update: $services"

    # Step 6: Update docker-compose.yml
    for svc in $services; do
        update_compose_file "$svc" "$new_version"
    done

    # Step 7: Pull new image
    log INFO "Pulling new Docker images..."
    if ! docker compose pull $services 2>&1 | tee -a "$LOG_FILE"; then
        log ERROR "Failed to pull new images"
        log INFO "Restoring docker-compose.yml..."
        cp "$backup_compose" "$COMPOSE_FILE"
        exit 1
    fi

    # Step 8: Recreate containers
    log INFO "Recreating containers..."
    docker compose up -d --force-recreate $services 2>&1 | tee -a "$LOG_FILE"

    # Step 9: Monitor logs
    log INFO "Monitoring startup logs for 60 seconds..."
    echo -e "${BLUE}Press Ctrl+C to skip monitoring (service will continue starting)${NC}"
    timeout 60 docker compose logs -f $services 2>&1 | tee -a "$LOG_FILE" || true

    # Step 10: Health checks
    log INFO "Running health checks..."
    local health_failed=false
    for svc in $services; do
        if ! check_health "$svc"; then
            health_failed=true
            break
        fi
    done

    # Step 11: Check logs for errors
    local logs_have_errors=false
    if ! $health_failed; then
        for svc in $services; do
            if ! check_logs_for_errors "$svc"; then
                logs_have_errors=true
                break
            fi
        done
    fi

    # Step 12: Report and offer rollback
    if $health_failed || $logs_have_errors; then
        log ERROR "Update validation failed"
        log INFO "Old version: $current_version"
        log INFO "New version: $new_version"

        echo
        read -p "Rollback to previous version? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            rollback "$service" "$backup_compose"
        else
            log WARNING "Rollback skipped - service may be unstable"
            log INFO "Manual rollback: cp $backup_compose $COMPOSE_FILE && docker compose up -d --force-recreate $services"
        fi
        exit 1
    else
        log SUCCESS "========================================="
        log SUCCESS "Update completed successfully!"
        log SUCCESS "Service: $service"
        log SUCCESS "Old version: $current_version"
        log SUCCESS "New version: $new_version"
        log SUCCESS "========================================="

        # Clean up old backup (keep recent 10)
        find "$BACKUP_DIR" -name "${service}_*" -type f | sort -r | tail -n +11 | xargs rm -f 2>/dev/null || true
    fi
}

# Usage
usage() {
    cat << EOF
Usage: $0 SERVICE_NAME [NEW_VERSION]

Update a BorgStack service to a specific version.

Arguments:
  SERVICE_NAME    Name of the service to update (required)
  NEW_VERSION     Target version (optional, prompts if not provided)

Examples:
  $0 n8n 1.113.0
  $0 postgresql 18.1
  $0 lowcoder-api-service 2.7.5

Available services:
$(docker compose config --services | sed 's/^/  - /')

EOF
    exit 1
}

# Main script
main() {
    if [ $# -lt 1 ]; then
        usage
    fi

    local service="$1"
    local new_version="${2:-}"

    # Check if running from correct directory first
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo -e "${RED}❌ docker-compose.yml not found. Run this script from the borgstack directory${NC}"
        exit 1
    fi

    # Initialize directories
    init_directories

    if [ -z "$new_version" ]; then
        echo -e "${YELLOW}No version specified${NC}"
        read -p "Enter target version: " new_version

        if [ -z "$new_version" ]; then
            log ERROR "Version is required"
            exit 1
        fi
    fi

    update_service "$service" "$new_version"
}

main "$@"
