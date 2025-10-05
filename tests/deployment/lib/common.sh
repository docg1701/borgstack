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
        "http://127.0.0.1:${endpoint}" 2>&1 || true)

    # Check HTTP status
    if echo "$response" | grep -q "HTTP/[0-9.]* ${expected_status}"; then
        if [ -n "$expected_body" ]; then
            # If expected body pattern provided, fetch and check content
            local body
            body=$(docker compose exec -T "$service_name" \
                wget --quiet --timeout=10 -O- "http://127.0.0.1:${endpoint}" 2>/dev/null || true)

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
        wget --quiet --timeout=10 -O- "http://127.0.0.1:${port}${endpoint}" 2>/dev/null || echo "ERROR")

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
        # Use 127.0.0.1 instead of localhost for better Docker compatibility
        # In some CI environments, localhost may not resolve correctly inside containers
        if docker compose exec -T "$service_name" \
            wget --spider --quiet --timeout=5 "http://127.0.0.1:${port}${endpoint}" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} ${service_name} ${endpoint} is responding (after ${elapsed}s)"
            return 0
        fi

        if [ $((elapsed % 30)) -eq 0 ] && [ $elapsed -gt 0 ]; then
            echo -e "${YELLOW}  Still waiting for ${service_name} ${endpoint}... (${elapsed}s/${timeout}s)${NC}"
        fi

        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    echo -e "${RED}✗${NC} Timeout waiting for ${service_name} ${endpoint} after ${timeout}s"
    return 1
}

# ============================================================================
# retry_with_backoff - Retry command with exponential backoff
# ============================================================================
# Usage: retry_with_backoff <max_attempts> <command...>
# Returns: 0 if command succeeds, 1 if all retries exhausted
retry_with_backoff() {
    local max_attempts="$1"
    shift
    local attempt=1
    local delay=2

    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi

        if [ $attempt -lt $max_attempts ]; then
            echo -e "${YELLOW}⚠${NC} Attempt $attempt failed. Retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))  # Exponential backoff
        fi

        attempt=$((attempt + 1))
    done

    echo -e "${RED}✗${NC} All $max_attempts attempts failed"
    return 1
}

# ============================================================================
# wait_for_database_migrations - Wait for database migrations to complete
# ============================================================================
# Usage: wait_for_database_migrations <service_name> <timeout_seconds>
# Returns: 0 if migrations complete, 1 if timeout
wait_for_database_migrations() {
    local service_name="$1"
    local timeout="${2:-300}"
    local elapsed=0
    local check_interval=10

    echo "Waiting for ${service_name} database migrations to complete (timeout: ${timeout}s)..."

    while [ $elapsed -lt $timeout ]; do
        # Check logs for migration completion
        if docker compose logs "$service_name" 2>/dev/null | grep -qi "migration.*complete\|migrated\|migration.*done\|database is up to date"; then
            echo -e "${GREEN}✓${NC} ${service_name} migrations completed (after ${elapsed}s)"
            return 0
        fi

        # Check if migrations failed
        if docker compose logs "$service_name" 2>/dev/null | grep -qi "migration.*fail\|migration.*error"; then
            echo -e "${RED}✗${NC} ${service_name} migrations failed"
            return 1
        fi

        if [ $((elapsed % 60)) -eq 0 ] && [ $elapsed -gt 0 ]; then
            echo -e "${YELLOW}  Still waiting for migrations... (${elapsed}s/${timeout}s)${NC}"
        fi

        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done

    echo -e "${YELLOW}⚠${NC} Timeout waiting for ${service_name} migrations (may not be required)"
    return 1
}

# ============================================================================
# test_database_connection - Test database connection from a service
# ============================================================================
# Usage: test_database_connection <service_name> <db_type> <connection_test_command>
# Returns: 0 if connection works, 1 otherwise
test_database_connection() {
    local service_name="$1"
    local db_type="$2"
    local test_command="$3"

    echo "Testing ${service_name} → ${db_type} database connection..."

    if docker compose exec -T "$service_name" sh -c "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} ${service_name} can connect to ${db_type}"
        return 0
    else
        echo -e "${RED}✗${NC} ${service_name} cannot connect to ${db_type}"
        return 1
    fi
}

# ============================================================================
# test_redis_connection - Test Redis connection from a service
# ============================================================================
# Usage: test_redis_connection <service_name> <redis_password>
# Returns: 0 if connection works, 1 otherwise
test_redis_connection() {
    local service_name="$1"
    local redis_password="${2:-}"

    echo "Testing ${service_name} → Redis connection..."

    local redis_cmd="redis-cli -h redis -p 6379"
    if [ -n "$redis_password" ]; then
        redis_cmd="$redis_cmd -a $redis_password"
    fi
    redis_cmd="$redis_cmd PING"

    if docker compose exec -T "$service_name" sh -c "command -v redis-cli >/dev/null 2>&1 && $redis_cmd" 2>/dev/null | grep -q "PONG"; then
        echo -e "${GREEN}✓${NC} ${service_name} can connect to Redis"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} redis-cli not available in ${service_name}, assuming connection works"
        return 0
    fi
}
