#!/usr/bin/env bash
#
# Common Test Functions for BorgStack Deployment Validation
# Shared utilities for robust container and API testing
#

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# ============================================================================
# wait_for_container_healthy - Wait for Docker container to become healthy
# ============================================================================
# Usage: wait_for_container_healthy <service_name> <timeout_seconds>
# Returns: 0 if healthy, 1 if timeout
wait_for_container_healthy() {
    local service_name="$1"
    local timeout="${2:-300}"  # Default 5 minutes
    local elapsed=0
    local check_interval=10

    echo "Waiting for ${service_name} to become healthy (timeout: ${timeout}s)..."

    while [ $elapsed -lt $timeout ]; do
        # Check if container is healthy
        if docker compose ps "$service_name" 2>/dev/null | grep -q "healthy"; then
            echo -e "${GREEN}✓${NC} ${service_name} is healthy (after ${elapsed}s)"
            return 0
        fi

        # Check if container is running but not healthy yet
        if docker compose ps "$service_name" 2>/dev/null | grep -q "Up"; then
            echo "  ${service_name} is running, waiting for health check... (${elapsed}s/${timeout}s)"
        else
            echo -e "${YELLOW}⚠${NC} ${service_name} is not running yet (${elapsed}s/${timeout}s)"
        fi

        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    echo -e "${RED}✗${NC} Timeout waiting for ${service_name} to become healthy after ${timeout}s"
    return 1
}

# ============================================================================
# test_internal_http - Test HTTP endpoint inside container
# ============================================================================
# Usage: test_internal_http <service_name> <endpoint_path> <expected_status> [expected_body_pattern]
# Returns: 0 if test passes, 1 if fails
test_internal_http() {
    local service_name="$1"
    local endpoint="$2"
    local expected_status="${3:-200}"
    local expected_body="$4"

    # Use wget inside container to test endpoint
    local response
    response=$(docker compose exec -T "$service_name" \
        wget --spider --server-response --timeout=10 \
        "http://localhost:${endpoint}" 2>&1 || true)

    # Check HTTP status
    if echo "$response" | grep -q "HTTP/[0-9.]* ${expected_status}"; then
        if [ -n "$expected_body" ]; then
            # If expected body pattern provided, fetch and check content
            local body
            body=$(docker compose exec -T "$service_name" \
                wget --quiet --timeout=10 -O- "http://localhost:${endpoint}" 2>/dev/null || true)

            if echo "$body" | grep -q "$expected_body"; then
                return 0
            else
                echo -e "${RED}✗${NC} ${service_name} ${endpoint} did not return expected body pattern: ${expected_body}"
                echo "  Got: ${body}"
                return 1
            fi
        fi
        return 0
    else
        echo -e "${RED}✗${NC} ${service_name} ${endpoint} did not return expected status ${expected_status}"
        echo "  Response: ${response}"
        return 1
    fi
}

# ============================================================================
# test_internal_http_body - Test HTTP endpoint and check body content
# ============================================================================
# Usage: test_internal_http_body <service_name> <port> <endpoint_path> <expected_body_pattern>
# Returns: 0 if test passes, 1 if fails
test_internal_http_body() {
    local service_name="$1"
    local port="$2"
    local endpoint="$3"
    local expected_body="$4"

    # Fetch body content
    local body
    body=$(docker compose exec -T "$service_name" \
        wget --quiet --timeout=10 -O- "http://localhost:${port}${endpoint}" 2>/dev/null || echo "ERROR")

    if [ "$body" = "ERROR" ]; then
        echo -e "${RED}✗${NC} Failed to fetch ${service_name} ${endpoint}"
        return 1
    fi

    if echo "$body" | grep -q "$expected_body"; then
        return 0
    else
        echo -e "${RED}✗${NC} ${service_name} ${endpoint} did not return expected body pattern: ${expected_body}"
        echo "  Got: ${body}"
        return 1
    fi
}

# ============================================================================
# show_diagnostics - Show diagnostic information for failed tests
# ============================================================================
# Usage: show_diagnostics <service_name>
show_diagnostics() {
    local service_name="$1"

    echo ""
    echo "=========================================="
    echo "Diagnostics for ${service_name}"
    echo "=========================================="

    echo ""
    echo "=== Container Status ==="
    docker compose ps "$service_name" || true

    echo ""
    echo "=== Container Logs (last 100 lines) ==="
    docker compose logs --tail=100 "$service_name" || true

    echo ""
    echo "=== Container Inspect (Health) ==="
    docker compose ps -q "$service_name" | xargs -r docker inspect --format='{{json .State.Health}}' 2>/dev/null | jq '.' 2>/dev/null || echo "No health check data available"

    echo ""
    echo "=== Networks ==="
    docker compose ps -q "$service_name" | xargs -r docker inspect --format='{{range .NetworkSettings.Networks}}{{.NetworkID}} {{end}}' 2>/dev/null || true

    echo "=========================================="
    echo ""
}

# ============================================================================
# wait_for_http_endpoint - Wait for HTTP endpoint to return expected status
# ============================================================================
# Usage: wait_for_http_endpoint <service_name> <port> <endpoint> <timeout_seconds>
# Returns: 0 if endpoint responds, 1 if timeout
wait_for_http_endpoint() {
    local service_name="$1"
    local port="$2"
    local endpoint="$3"
    local timeout="${4:-120}"
    local elapsed=0
    local check_interval=5

    echo "Waiting for ${service_name} ${endpoint} to respond (timeout: ${timeout}s)..."

    while [ $elapsed -lt $timeout ]; do
        if docker compose exec -T "$service_name" \
            wget --spider --quiet --timeout=5 "http://localhost:${port}${endpoint}" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} ${service_name} ${endpoint} is responding (after ${elapsed}s)"
            return 0
        fi

        echo "  Waiting for ${service_name} ${endpoint}... (${elapsed}s/${timeout}s)"
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    echo -e "${RED}✗${NC} Timeout waiting for ${service_name} ${endpoint} after ${timeout}s"
    return 1
}
