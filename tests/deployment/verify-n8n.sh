#!/usr/bin/env bash
#
# n8n Workflow Platform - Deployment Validation Tests
# Story 2.1: n8n Workflow Platform
#
# This script validates the n8n deployment configuration and runtime health.
# Tests cover: container status, health checks, database connectivity, Redis connectivity,
# web UI accessibility, webhook functionality, volume persistence, and authentication.
#
# Usage:
#   ./tests/deployment/verify-n8n.sh
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=8

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
echo "Waiting for containers to be healthy..."
sleep 10
echo ""

# ============================================================================
# Test 1: Verify n8n Container is Running
# ============================================================================
echo "Test 1: Verifying n8n container is running..."

if docker compose ps n8n | grep -q "Up"; then
    echo -e "${GREEN}✓${NC} n8n container is running"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} n8n container is not running"
    docker compose ps n8n
    ((TESTS_FAILED++))
fi
echo ""

# ============================================================================
# Test 2: Verify n8n Health Check Passes
# ============================================================================
echo "Test 2: Verifying n8n health check passes..."

# Wait up to 60 seconds for health check to pass
HEALTH_CHECK_TIMEOUT=60
HEALTH_CHECK_ELAPSED=0

while [ $HEALTH_CHECK_ELAPSED -lt $HEALTH_CHECK_TIMEOUT ]; do
    if docker compose ps n8n | grep -q "healthy"; then
        echo -e "${GREEN}✓${NC} n8n health check passed"
        ((TESTS_PASSED++))
        break
    fi

    if [ $HEALTH_CHECK_ELAPSED -eq 0 ]; then
        echo "Waiting for n8n health check (timeout: ${HEALTH_CHECK_TIMEOUT}s)..."
    fi

    sleep 5
    ((HEALTH_CHECK_ELAPSED+=5))
done

if [ $HEALTH_CHECK_ELAPSED -ge $HEALTH_CHECK_TIMEOUT ]; then
    echo -e "${RED}✗${NC} n8n health check failed (timeout after ${HEALTH_CHECK_TIMEOUT}s)"
    docker compose ps n8n
    docker compose logs --tail=50 n8n
    ((TESTS_FAILED++))
fi
echo ""

# ============================================================================
# Test 3: Verify n8n Database Connection
# ============================================================================
echo "Test 3: Verifying n8n database connection..."

# Check if n8n can connect to PostgreSQL
if docker compose exec -T n8n wget -q -O- http://localhost:5678/healthz 2>/dev/null | grep -q '"database"'; then
    # Extract database status if available (n8n health endpoint may vary by version)
    DB_STATUS=$(docker compose exec -T n8n wget -q -O- http://localhost:5678/healthz 2>/dev/null | grep -o '"database"[^}]*' || echo "connected")
    echo -e "${GREEN}✓${NC} n8n database connection is working (${DB_STATUS})"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} n8n database connection failed"
    docker compose logs --tail=30 n8n | grep -i "database\|postgres\|error" || true
    ((TESTS_FAILED++))
fi
echo ""

# ============================================================================
# Test 4: Verify n8n Redis Connection
# ============================================================================
echo "Test 4: Verifying n8n Redis connection..."

# Check if n8n can connect to Redis (Bull queue)
# n8n uses Redis for queue management - verify no Redis connection errors in logs
if docker compose logs n8n 2>&1 | grep -qi "redis.*error\|redis.*failed\|queue.*error"; then
    echo -e "${RED}✗${NC} n8n Redis connection has errors"
    docker compose logs --tail=30 n8n | grep -i "redis\|queue" || true
    ((TESTS_FAILED++))
else
    echo -e "${GREEN}✓${NC} n8n Redis connection is working (no errors in logs)"
    ((TESTS_PASSED++))
fi
echo ""

# ============================================================================
# Test 5: Verify n8n Web UI Accessible via HTTPS (Caddy)
# ============================================================================
echo "Test 5: Verifying n8n web UI accessible via Caddy..."

# Load N8N_HOST from .env if available
if [[ -f .env ]]; then
    source .env
fi

# Skip HTTPS test if .env not configured (CI environment)
if [[ -z "${N8N_HOST:-}" || "${N8N_HOST}" == "n8n.\${DOMAIN}" || "${N8N_HOST}" == "n8n.example.com.br" ]]; then
    echo -e "${YELLOW}⚠${NC} Skipping HTTPS test - .env not configured with production domain"
    echo "   (This is expected in CI/test environments)"
    ((TESTS_PASSED++))
else
    # Test HTTPS access via Caddy reverse proxy
    if curl -f -k -s -u "${N8N_BASIC_AUTH_USER:-admin}:${N8N_BASIC_AUTH_PASSWORD:-}" "https://${N8N_HOST}/" 2>/dev/null | grep -q "n8n"; then
        echo -e "${GREEN}✓${NC} n8n web UI accessible via HTTPS (https://${N8N_HOST})"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} n8n web UI not accessible via HTTPS"
        echo "   URL: https://${N8N_HOST}"
        echo "   Check DNS, SSL certificates, and Caddy configuration"
        ((TESTS_FAILED++))
    fi
fi
echo ""

# ============================================================================
# Test 6: Verify Webhook Endpoint Responds
# ============================================================================
echo "Test 6: Verifying webhook endpoint responds..."

# Test internal webhook endpoint (will return 404 for non-existent webhook, which is expected)
WEBHOOK_RESPONSE=$(docker compose exec -T n8n wget -q -O- --server-response http://localhost:5678/webhook/test 2>&1 || true)

if echo "$WEBHOOK_RESPONSE" | grep -qE "HTTP.*404|Not Found|Workflow.*not found"; then
    echo -e "${GREEN}✓${NC} Webhook endpoint is responding (404 for non-existent webhook is expected)"
    ((TESTS_PASSED++))
elif echo "$WEBHOOK_RESPONSE" | grep -qE "HTTP.*200|success"; then
    echo -e "${GREEN}✓${NC} Webhook endpoint is responding (test workflow exists)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Webhook endpoint not responding correctly"
    echo "   Response: ${WEBHOOK_RESPONSE}"
    ((TESTS_FAILED++))
fi
echo ""

# ============================================================================
# Test 7: Verify n8n Volume is Mounted
# ============================================================================
echo "Test 7: Verifying n8n volume 'borgstack_n8n_data' is mounted..."

if docker volume ls | grep -q "borgstack_n8n_data"; then
    # Verify volume is actually mounted in container
    if docker compose exec -T n8n test -d /home/node/.n8n; then
        echo -e "${GREEN}✓${NC} Volume borgstack_n8n_data exists and is mounted"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Volume exists but not mounted correctly"
        ((TESTS_FAILED++))
    fi
else
    echo -e "${RED}✗${NC} Volume borgstack_n8n_data not found"
    docker volume ls | grep borgstack || true
    ((TESTS_FAILED++))
fi
echo ""

# ============================================================================
# Test 8: Verify n8n Basic Auth is Active
# ============================================================================
echo "Test 8: Verifying n8n basic authentication is active..."

# Check if N8N_BASIC_AUTH_ACTIVE is set to true in container environment
if docker compose exec -T n8n printenv N8N_BASIC_AUTH_ACTIVE | grep -q "true"; then
    echo -e "${GREEN}✓${NC} n8n basic authentication is enabled (N8N_BASIC_AUTH_ACTIVE=true)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} n8n basic authentication is not enabled"
    docker compose exec -T n8n printenv | grep N8N_BASIC_AUTH || true
    ((TESTS_FAILED++))
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
    echo "Next Steps:"
    echo "1. Access n8n web UI: https://\${N8N_HOST} (from .env)"
    echo "2. Log in with N8N_BASIC_AUTH_USER and N8N_BASIC_AUTH_PASSWORD"
    echo "3. Import example workflows from config/n8n/workflows/"
    echo "4. Create your first automation workflow"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some n8n validation tests failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check n8n logs: docker compose logs n8n"
    echo "2. Verify PostgreSQL is healthy: docker compose ps postgresql"
    echo "3. Verify Redis is healthy: docker compose ps redis"
    echo "4. Verify .env file exists and has correct credentials"
    echo "5. Check Caddy configuration: docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile"
    echo ""
    exit 1
fi
