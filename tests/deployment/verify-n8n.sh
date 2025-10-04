#!/usr/bin/env bash
#
# n8n Workflow Platform - Deployment Validation Tests
# Story 2.1: n8n Workflow Platform
#
# This script validates the n8n deployment configuration and runtime health.
# Based on official n8n documentation from https://docs.n8n.io/hosting/logging-monitoring/monitoring/
#
# Official Health Check Endpoints:
#   - GET /healthz           - Returns 200 if instance is reachable (basic liveness)
#   - GET /healthz/readiness - Returns 200 if database connected and migrated (full readiness)
#   - GET /metrics           - Detailed metrics (requires N8N_METRICS=true)
#
# Usage:
#   ./tests/deployment/verify-n8n.sh
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed
#

set -euo pipefail

# Load common test functions
SCRIPT_DIR="$(dirname "$0")"
# shellcheck source=tests/deployment/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=9

# Navigate to project root
cd "$(dirname "$0")/../.."

echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo "n8n Workflow Platform - Deployment Validation Tests"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# Setup: Start n8n and dependencies
# ============================================================================
echo "Starting n8n and dependencies..."
docker compose up -d postgresql redis n8n

echo ""
echo "Waiting for containers to become healthy..."
echo "Note: n8n needs time for database migrations and initialization"
echo ""

# ============================================================================
# Test 1: Verify PostgreSQL Container is Healthy
# ============================================================================
echo "Test 1: Waiting for PostgreSQL to become healthy..."

if wait_for_container_healthy "postgresql" 180; then
    echo -e "${GREEN}✓${NC} PostgreSQL container is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} PostgreSQL container failed to become healthy"
    show_diagnostics "postgresql"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 2: Verify Redis Container is Healthy
# ============================================================================
echo "Test 2: Waiting for Redis to become healthy..."

if wait_for_container_healthy "redis" 60; then
    echo -e "${GREEN}✓${NC} Redis container is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Redis container failed to become healthy"
    show_diagnostics "redis"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 3: Verify n8n Container is Healthy
# ============================================================================
echo "Test 3: Waiting for n8n to become healthy..."
echo "Note: n8n start_period is 90s, allowing time for database migrations"

if wait_for_container_healthy "n8n" 300; then
    echo -e "${GREEN}✓${NC} n8n container is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} n8n container failed to become healthy"
    show_diagnostics "n8n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 4: Verify n8n /healthz Endpoint (Basic Liveness)
# ============================================================================
echo "Test 4: Verifying n8n /healthz endpoint (basic liveness check)..."

if wait_for_http_endpoint "n8n" "5678" "/healthz" 60; then
    echo -e "${GREEN}✓${NC} n8n /healthz endpoint is accessible (instance is reachable)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} n8n /healthz endpoint is not accessible"
    show_diagnostics "n8n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 5: Verify n8n /healthz/readiness Endpoint (Full Readiness)
# ============================================================================
echo "Test 5: Verifying n8n /healthz/readiness endpoint (database connected and migrated)..."

if wait_for_http_endpoint "n8n" "5678" "/healthz/readiness" 60; then
    echo -e "${GREEN}✓${NC} n8n /healthz/readiness endpoint returns 200 (database ready)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} n8n /healthz/readiness endpoint failed"
    echo ""
    echo "=== n8n /healthz/readiness Response ==="
    docker compose exec -T n8n wget --quiet -O- http://localhost:5678/healthz/readiness 2>&1 || echo "(no response)"
    echo "======================================="
    show_diagnostics "n8n"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 6: Verify n8n Database Connection (via environment variables)
# ============================================================================
echo "Test 6: Verifying n8n database configuration..."

DB_TYPE=$(docker compose exec -T n8n printenv DB_TYPE 2>/dev/null || echo "")
DB_HOST=$(docker compose exec -T n8n printenv DB_POSTGRESDB_HOST 2>/dev/null || echo "")
DB_NAME=$(docker compose exec -T n8n printenv DB_POSTGRESDB_DATABASE 2>/dev/null || echo "")

if [ "$DB_TYPE" = "postgresdb" ] && [ "$DB_HOST" = "postgresql" ] && [ "$DB_NAME" = "n8n_db" ]; then
    echo -e "${GREEN}✓${NC} n8n database configuration is correct"
    echo "   DB_TYPE=${DB_TYPE}, DB_HOST=${DB_HOST}, DB_DATABASE=${DB_NAME}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} n8n database configuration is incorrect"
    echo "   DB_TYPE=${DB_TYPE}, DB_HOST=${DB_HOST}, DB_DATABASE=${DB_NAME}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 7: Verify n8n Redis Connection (via environment variables)
# ============================================================================
echo "Test 7: Verifying n8n Redis configuration..."

REDIS_HOST=$(docker compose exec -T n8n printenv QUEUE_BULL_REDIS_HOST 2>/dev/null || echo "")
REDIS_PORT=$(docker compose exec -T n8n printenv QUEUE_BULL_REDIS_PORT 2>/dev/null || echo "")

if [ "$REDIS_HOST" = "redis" ] && [ "$REDIS_PORT" = "6379" ]; then
    echo -e "${GREEN}✓${NC} n8n Redis configuration is correct"
    echo "   REDIS_HOST=${REDIS_HOST}, REDIS_PORT=${REDIS_PORT}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} n8n Redis configuration is incorrect"
    echo "   REDIS_HOST=${REDIS_HOST}, REDIS_PORT=${REDIS_PORT}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 8: Verify n8n Volume is Mounted
# ============================================================================
echo "Test 8: Verifying n8n volume 'borgstack_n8n_data' is mounted..."

if docker volume ls | grep -q "borgstack_n8n_data"; then
    # Verify volume is actually mounted in container
    if docker compose exec -T n8n test -d /home/node/.n8n 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Volume borgstack_n8n_data exists and is mounted at /home/node/.n8n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Volume exists but not mounted correctly"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${RED}✗${NC} Volume borgstack_n8n_data not found"
    docker volume ls | grep borgstack || true
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 9: Verify n8n Basic Auth is Active
# ============================================================================
echo "Test 9: Verifying n8n basic authentication is active..."

N8N_BASIC_AUTH=$(docker compose exec -T n8n printenv N8N_BASIC_AUTH_ACTIVE 2>/dev/null || echo "")

if [ "$N8N_BASIC_AUTH" = "true" ]; then
    echo -e "${GREEN}✓${NC} n8n basic authentication is enabled (N8N_BASIC_AUTH_ACTIVE=true)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} n8n basic authentication is not enabled"
    echo "   N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test Summary
# ============================================================================
echo "═══════════════════════════════════════════════════════════════════════════"
echo "Test Summary"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "Total Tests: ${TOTAL_TESTS}"
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All n8n validation tests passed!${NC}"
    echo ""
    echo "n8n is ready for use:"
    echo "  - Health check: http://localhost:5678/healthz/readiness"
    echo "  - Web UI: https://\${N8N_HOST} (configured in .env)"
    echo "  - Credentials: N8N_BASIC_AUTH_USER / N8N_BASIC_AUTH_PASSWORD"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some n8n validation tests failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check n8n logs: docker compose logs n8n"
    echo "  2. Check PostgreSQL: docker compose ps postgresql"
    echo "  3. Check Redis: docker compose ps redis"
    echo "  4. Verify .env file has all required variables"
    echo "  5. Check database migrations: docker compose exec n8n ls -la /home/node/.n8n"
    echo ""
    exit 1
fi
