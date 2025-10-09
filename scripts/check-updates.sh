#!/bin/bash
# check-updates.sh - BorgStack Update Availability Checker
#
# Usage:
#   ./scripts/check-updates.sh [--email]
#
# Description:
#   Checks Docker Hub for available updates for all BorgStack services.
#   Compares current versions with latest stable versions available.
#   Optionally sends email notification if updates are available.
#
# Docker Hub API Authentication (Optional):
#   For higher rate limits, set DOCKER_HUB_TOKEN environment variable.
#   Generate token at: https://hub.docker.com/settings/security
#   Without token: 100 requests / 6 hours
#   With token: 200 requests / 6 hours
#
#   Usage: DOCKER_HUB_TOKEN="your-token" ./scripts/check-updates.sh
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.yml"
SEND_EMAIL=false
EMAIL_TO="${BORGSTACK_ADMIN_EMAIL:-admin@localhost}"
TEMP_FILE="/tmp/borgstack-updates-check.txt"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --email)
            SEND_EMAIL=true
            shift
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [--email]"
            exit 1
            ;;
    esac
done

# Check if running from correct directory
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}❌ docker-compose.yml not found. Run this script from the borgstack directory${NC}"
    exit 1
fi

# Service image mappings (extracted from docker-compose.yml)
declare -A SERVICE_IMAGES=(
    ["n8n"]="n8nio/n8n"
    ["chatwoot"]="chatwoot/chatwoot"
    ["directus"]="directus/directus"
    ["evolution"]="atendai/evolution-api"
    ["postgresql"]="pgvector/pgvector"
    ["mongodb"]="mongo"
    ["redis"]="redis"
    ["caddy"]="caddy"
    ["seaweedfs"]="chrislusf/seaweedfs"
    ["lowcoder-api-service"]="lowcoderorg/lowcoder-ce"
    ["lowcoder-node-service"]="lowcoderorg/lowcoder-ce"
    ["lowcoder-frontend"]="lowcoderorg/lowcoder-ce"
    ["duplicati"]="duplicati/duplicati"
    ["fileflows"]="revenz/fileflows"
)

# Get current version of service
get_current_version() {
    local service="$1"
    docker compose images "$service" 2>/dev/null | grep "$service" | awk '{print $2}' | head -1
}

# Query Docker Hub API for latest version
get_latest_version() {
    local image="$1"
    local current_tag="$2"

    # Extract repo and name
    local repo_name="$image"

    # Prepare API URL
    local api_url="https://hub.docker.com/v2/repositories/${repo_name}/tags/?page_size=100"

    # Add authentication if token available
    local auth_header=""
    if [ -n "${DOCKER_HUB_TOKEN:-}" ]; then
        auth_header="-H \"Authorization: Bearer ${DOCKER_HUB_TOKEN}\""
    fi

    # Query API with exponential backoff
    local max_retries=3
    local retry=0
    local response=""

    while [ $retry -lt $max_retries ]; do
        if [ -n "$auth_header" ]; then
            response=$(curl -s $auth_header "$api_url" 2>/dev/null || echo "")
        else
            response=$(curl -s "$api_url" 2>/dev/null || echo "")
        fi

        if [ -n "$response" ] && [ "$response" != "null" ]; then
            break
        fi

        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            sleep $((2 ** retry))  # Exponential backoff: 2s, 4s, 8s
        fi
    done

    # If API failed, fallback to dry-run method
    if [ -z "$response" ] || [ "$response" = "null" ]; then
        echo "unknown"
        return
    fi

    # Parse JSON to find latest stable version (exclude alpha, beta, rc, dev)
    local latest=$(echo "$response" | \
        jq -r '.results[].name' 2>/dev/null | \
        grep -v -iE 'alpha|beta|rc|dev|test|snapshot|nightly' | \
        grep -E '^[0-9v]' | \
        head -1)

    if [ -z "$latest" ] || [ "$latest" = "null" ]; then
        echo "unknown"
    else
        echo "$latest"
    fi
}

# Determine update type (major, minor, patch)
get_update_type() {
    local current="$1"
    local latest="$2"

    # Remove 'v' prefix if present
    current="${current#v}"
    latest="${latest#v}"

    # Handle special formats (e.g., pg18, 8.2-alpine)
    if [[ ! "$current" =~ ^[0-9]+\.[0-9]+\.?[0-9]* ]]; then
        echo "unknown"
        return
    fi

    # Extract version components
    local current_major=$(echo "$current" | cut -d. -f1 | grep -oE '[0-9]+')
    local current_minor=$(echo "$current" | cut -d. -f2 | grep -oE '[0-9]+' || echo "0")
    local current_patch=$(echo "$current" | cut -d. -f3 | grep -oE '[0-9]+' || echo "0")

    local latest_major=$(echo "$latest" | cut -d. -f1 | grep -oE '[0-9]+')
    local latest_minor=$(echo "$latest" | cut -d. -f2 | grep -oE '[0-9]+' || echo "0")
    local latest_patch=$(echo "$latest" | cut -d. -f3 | grep -oE '[0-9]+' || echo "0")

    # Compare versions
    if [ "$latest_major" -gt "$current_major" ]; then
        echo "major"
    elif [ "$latest_major" -eq "$current_major" ] && [ "$latest_minor" -gt "$current_minor" ]; then
        echo "minor"
    elif [ "$latest_major" -eq "$current_major" ] && [ "$latest_minor" -eq "$current_minor" ] && [ "$latest_patch" -gt "$current_patch" ]; then
        echo "patch"
    else
        echo "none"
    fi
}

# Main check function
check_updates() {
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}BorgStack Update Availability Check${NC}"
    echo -e "${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""

    # Initialize counters
    local total_services=0
    local updates_available=0
    local check_failed=0

    # Header
    printf "%-25s %-20s %-20s %-10s\n" "SERVICE" "CURRENT" "LATEST" "UPDATE"
    echo "-----------------------------------------------------------------------------------------"

    # Check each service
    for service in "${!SERVICE_IMAGES[@]}"; do
        total_services=$((total_services + 1))

        local image="${SERVICE_IMAGES[$service]}"
        local current=$(get_current_version "$service")

        if [ -z "$current" ] || [ "$current" = "unknown" ]; then
            printf "%-25s %-20s %-20s %-10s\n" "$service" "not found" "-" "-"
            check_failed=$((check_failed + 1))
            continue
        fi

        local latest=$(get_latest_version "$image" "$current")

        if [ "$latest" = "unknown" ]; then
            printf "%-25s %-20s %-20s %-10s\n" "$service" "$current" "check failed" "-"
            check_failed=$((check_failed + 1))
            continue
        fi

        local update_type=$(get_update_type "$current" "$latest")

        # Color code output
        if [ "$update_type" = "major" ]; then
            updates_available=$((updates_available + 1))
            printf "%-25s %-20s ${RED}%-20s${NC} ${RED}%-10s${NC}\n" "$service" "$current" "$latest" "MAJOR"
        elif [ "$update_type" = "minor" ]; then
            updates_available=$((updates_available + 1))
            printf "%-25s %-20s ${YELLOW}%-20s${NC} ${YELLOW}%-10s${NC}\n" "$service" "$current" "$latest" "MINOR"
        elif [ "$update_type" = "patch" ]; then
            updates_available=$((updates_available + 1))
            printf "%-25s %-20s ${GREEN}%-20s${NC} ${GREEN}%-10s${NC}\n" "$service" "$current" "$latest" "PATCH"
        else
            printf "%-25s %-20s %-20s %-10s\n" "$service" "$current" "$latest" "up-to-date"
        fi
    done

    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "Total services: $total_services"
    echo -e "Updates available: ${YELLOW}$updates_available${NC}"
    echo -e "Check failures: ${RED}$check_failed${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""

    # Return status
    if [ $updates_available -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Email notification function
send_email_notification() {
    if ! command -v mail &> /dev/null; then
        echo -e "${YELLOW}⚠️  'mail' command not found. Install mailutils to enable email notifications.${NC}"
        return 1
    fi

    local subject="BorgStack Updates Available - $(hostname)"
    local body=$(cat "$TEMP_FILE")

    echo "$body" | mail -s "$subject" "$EMAIL_TO"
    echo -e "${GREEN}✅ Email notification sent to $EMAIL_TO${NC}"
}

# Main execution
main() {
    # Run check and save to temp file
    check_updates | tee "$TEMP_FILE"
    local updates_available=$?

    # Send email if requested and updates available
    if [ "$SEND_EMAIL" = true ] && [ $updates_available -eq 0 ]; then
        send_email_notification
    fi

    # Cleanup
    rm -f "$TEMP_FILE"

    echo ""
    echo "To update a service:"
    echo "  ./scripts/update-service.sh SERVICE_NAME NEW_VERSION"
    echo ""
    echo "Example:"
    echo "  ./scripts/update-service.sh n8n 1.113.0"
    echo ""
}

main "$@"
