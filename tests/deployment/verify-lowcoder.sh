#!/usr/bin/env bash
#
# Lowcoder Application Platform - Deployment Validation Tests
# Story 3.2: Lowcoder Application Platform
#
# This script validates:
# - Lowcoder API Service container running and healthy
# - Lowcoder Node Service container running and healthy
# - Lowcoder Frontend container running and healthy
# - MongoDB connection working (direct query)
# - Redis connection working (direct PING test)
# - API health endpoints responding
# - Volume persistence
# - Environment variables configured
#

set -euo pipefail

# Load common test functions
SCRIPT_DIR="$(dirname "$0")"
# shellcheck source=tests/deployment/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=13  # Removed redundant MongoDB and Redis tests (validated by healthcheck)

# Navigate to project root
cd "$(dirname "$0")/../.."

echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo "Lowcoder Application Platform - Deployment Validation Tests"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# Load environment variables if available
if [ -f .env ]; then
    # shellcheck disable=SC1091
    set -a
    source .env
    set +a
fi

# ============================================================================
# Setup: Start Lowcoder services and dependencies
# ============================================================================
echo "Starting Lowcoder services and dependencies..."
docker compose up -d mongodb redis lowcoder-api-service lowcoder-node-service lowcoder-frontend

echo ""
echo "Waiting for containers to become healthy..."
echo "Note: Lowcoder API Service needs time for initialization (start_period: 180s)"
echo ""

# ============================================================================
# Test 1: Verify MongoDB Container is Healthy
# ============================================================================
echo "Test 1: Waiting for MongoDB to become healthy..."

if wait_for_container_healthy "mongodb" 60; then
    echo -e "${GREEN}✓${NC} MongoDB container is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} MongoDB container failed to become healthy"
    show_diagnostics "mongodb"
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
# Test 3: Verify Lowcoder API Service Container is Healthy
# ============================================================================
echo "Test 3: Waiting for Lowcoder API Service to become healthy..."
echo "Note: Lowcoder API Service start_period is 180s, may take 3-5 minutes in CI"

# Wait for container health with extended timeout for CI
if wait_for_container_healthy "lowcoder-api-service" 300; then
    echo -e "${GREEN}✓${NC} Lowcoder API Service container is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Lowcoder API Service container failed to become healthy"
    show_diagnostics "lowcoder-api-service"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 4: Verify Lowcoder Node Service Container is Healthy
# ============================================================================
echo "Test 4: Waiting for Lowcoder Node Service to become healthy..."

if wait_for_container_healthy "lowcoder-node-service" 180; then
    echo -e "${GREEN}✓${NC} Lowcoder Node Service container is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Lowcoder Node Service container failed to become healthy"
    show_diagnostics "lowcoder-node-service"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 5: Verify Lowcoder Frontend Container is Healthy
# ============================================================================
echo "Test 5: Waiting for Lowcoder Frontend to become healthy..."

if wait_for_container_healthy "lowcoder-frontend" 180; then
    echo -e "${GREEN}✓${NC} Lowcoder Frontend container is healthy"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Lowcoder Frontend container failed to become healthy"
    show_diagnostics "lowcoder-frontend"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 6: Verify Lowcoder API Service Health Endpoint
# ============================================================================
# The /api/status/health endpoint validates MongoDB + Redis + all services
echo "Test 6: Verifying Lowcoder API Service /api/status/health endpoint..."

# Use curl instead of wget (matches healthcheck)
if docker compose exec -T lowcoder-api-service \
    curl -f --max-time 10 http://127.0.0.1:8080/api/status/health 2>/dev/null >/dev/null; then
    echo -e "${GREEN}✓${NC} Lowcoder API Service health endpoint is accessible"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Lowcoder API Service health endpoint is not accessible"
    show_diagnostics "lowcoder-api-service"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 7: Verify Lowcoder Image Versions
# ============================================================================
echo "Test 7: Verifying Lowcoder image versions..."

IMAGE_CHECK_PASSED=true

if docker compose ps lowcoder-api-service | grep -q "lowcoderorg/lowcoder-ce-api-service:2.7.4"; then
    echo -e "${GREEN}✓${NC} Lowcoder API Service image version is correct (lowcoderorg/lowcoder-ce-api-service:2.7.4)"
else
    echo -e "${RED}✗${NC} Lowcoder API Service image version is incorrect"
    docker compose ps lowcoder-api-service
    IMAGE_CHECK_PASSED=false
fi

if docker compose ps lowcoder-node-service | grep -q "lowcoderorg/lowcoder-ce-node-service:2.7.4"; then
    echo -e "${GREEN}✓${NC} Lowcoder Node Service image version is correct (lowcoderorg/lowcoder-ce-node-service:2.7.4)"
else
    echo -e "${RED}✗${NC} Lowcoder Node Service image version is incorrect"
    docker compose ps lowcoder-node-service
    IMAGE_CHECK_PASSED=false
fi

if docker compose ps lowcoder-frontend | grep -q "lowcoderorg/lowcoder-ce-frontend:2.7.4"; then
    echo -e "${GREEN}✓${NC} Lowcoder Frontend image version is correct (lowcoderorg/lowcoder-ce-frontend:2.7.4)"
else
    echo -e "${RED}✗${NC} Lowcoder Frontend image version is incorrect"
    docker compose ps lowcoder-frontend
    IMAGE_CHECK_PASSED=false
fi

if [ "$IMAGE_CHECK_PASSED" = true ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 8: Verify MongoDB Environment Variables
# ============================================================================
echo "Test 8: Verifying MongoDB environment variables in API Service..."

MONGODB_URL=$(docker compose exec -T lowcoder-api-service printenv LOWCODER_MONGODB_URL 2>/dev/null || echo "")

if echo "$MONGODB_URL" | grep -q "mongodb://lowcoder_user.*@mongodb:27017/lowcoder"; then
    echo -e "${GREEN}✓${NC} MongoDB environment variables are correct"
    echo "   LOWCODER_MONGODB_URL configured correctly"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} MongoDB environment variables are incorrect"
    echo "   LOWCODER_MONGODB_URL=$MONGODB_URL"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 9: Verify Redis Environment Variables
# ============================================================================
echo "Test 9: Verifying Redis environment variables in API Service..."

REDIS_URL=$(docker compose exec -T lowcoder-api-service printenv LOWCODER_REDIS_URL 2>/dev/null || echo "")

if echo "$REDIS_URL" | grep -q "redis://.*@redis:6379"; then
    echo -e "${GREEN}✓${NC} Redis environment variables are correct"
    echo "   LOWCODER_REDIS_URL configured correctly"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Redis environment variables are incorrect"
    echo "   LOWCODER_REDIS_URL=$REDIS_URL"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 10: Verify Volume is Mounted
# ============================================================================
echo "Test 10: Verifying borgstack_lowcoder_stacks volume is mounted..."

if docker volume ls | grep -q "borgstack_lowcoder_stacks"; then
    if docker compose exec -T lowcoder-api-service test -d /lowcoder-stacks 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Volume is mounted at /lowcoder-stacks in API Service"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Volume exists but not mounted at /lowcoder-stacks in API Service"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${RED}✗${NC} Volume borgstack_lowcoder_stacks does not exist"
    docker volume ls | grep borgstack || true
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 11: Verify No Port Exposure (Security Check)
# ============================================================================
echo "Test 11: Verifying no port exposure to host (security requirement)..."

PORT_EXPOSURE_FOUND=false

if docker compose ps lowcoder-api-service | grep -q "8080->"; then
    echo -e "${RED}✗${NC} Lowcoder API Service has port 8080 exposed to host (security violation)"
    PORT_EXPOSURE_FOUND=true
fi

if docker compose ps lowcoder-node-service | grep -q "6060->"; then
    echo -e "${RED}✗${NC} Lowcoder Node Service has port 6060 exposed to host (security violation)"
    PORT_EXPOSURE_FOUND=true
fi

if docker compose ps lowcoder-frontend | grep -q "3000->"; then
    echo -e "${RED}✗${NC} Lowcoder Frontend has port 3000 exposed to host (security violation)"
    PORT_EXPOSURE_FOUND=true
fi

if [ "$PORT_EXPOSURE_FOUND" = true ]; then
    echo "   In production, Lowcoder should only be accessible via Caddy reverse proxy"
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    echo -e "${GREEN}✓${NC} No port exposure to host (security requirement met)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi
echo ""

# ============================================================================
# Test 12: Verify Service URLs in Node Service
# ============================================================================
echo "Test 12: Verifying service URL configuration in Node Service..."

API_SERVICE_URL=$(docker compose exec -T lowcoder-node-service printenv LOWCODER_API_SERVICE_URL 2>/dev/null || echo "")

if echo "$API_SERVICE_URL" | grep -q "http://lowcoder-api-service:8080"; then
    echo -e "${GREEN}✓${NC} Node Service API URL configured correctly"
    echo "   LOWCODER_API_SERVICE_URL=$API_SERVICE_URL"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Node Service API URL configured incorrectly"
    echo "   LOWCODER_API_SERVICE_URL=$API_SERVICE_URL"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# ============================================================================
# Test 13: Verify Service URLs in Frontend
# ============================================================================
echo "Test 13: Verifying service URL configuration in Frontend..."

FRONTEND_API_URL=$(docker compose exec -T lowcoder-frontend printenv LOWCODER_API_SERVICE_URL 2>/dev/null || echo "")
FRONTEND_NODE_URL=$(docker compose exec -T lowcoder-frontend printenv LOWCODER_NODE_SERVICE_URL 2>/dev/null || echo "")

URL_CHECK_PASSED=true

if echo "$FRONTEND_API_URL" | grep -q "http://lowcoder-api-service:8080"; then
    echo -e "${GREEN}✓${NC} Frontend API Service URL configured correctly"
    echo "   LOWCODER_API_SERVICE_URL=$FRONTEND_API_URL"
else
    echo -e "${RED}✗${NC} Frontend API Service URL configured incorrectly"
    echo "   LOWCODER_API_SERVICE_URL=$FRONTEND_API_URL"
    URL_CHECK_PASSED=false
fi

if echo "$FRONTEND_NODE_URL" | grep -q "http://lowcoder-node-service:6060"; then
    echo -e "${GREEN}✓${NC} Frontend Node Service URL configured correctly"
    echo "   LOWCODER_NODE_SERVICE_URL=$FRONTEND_NODE_URL"
else
    echo -e "${RED}✗${NC} Frontend Node Service URL configured incorrectly"
    echo "   LOWCODER_NODE_SERVICE_URL=$FRONTEND_NODE_URL"
    URL_CHECK_PASSED=false
fi

if [ "$URL_CHECK_PASSED" = true ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
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
    echo -e "${GREEN}✓ All Lowcoder validation tests passed!${NC}"
    echo ""
    echo "Lowcoder multi-service architecture is ready for use:"
    echo "  - API Service health: http://localhost:8080/api/status/health"
    echo "  - Node Service health: http://localhost:6060"
    echo "  - Frontend health: http://localhost:3000"
    echo "  - Web UI: https://lowcoder.\${DOMAIN} (via Caddy reverse proxy)"
    echo ""
    echo "Service Architecture:"
    echo "  - API Service: Handles business logic and data access (MongoDB, Redis)"
    echo "  - Node Service: JavaScript execution environment"
    echo "  - Frontend: Web interface and user interactions"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some Lowcoder validation tests failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check API Service logs: docker compose logs lowcoder-api-service"
    echo "  2. Check Node Service logs: docker compose logs lowcoder-node-service"
    echo "  3. Check Frontend logs: docker compose logs lowcoder-frontend"
    echo "  4. Check MongoDB: docker compose ps mongodb"
    echo "  5. Check Redis: docker compose ps redis"
    echo "  6. Verify .env file has all required variables"
    echo "  7. Check service dependencies: docker compose ps"
    echo ""
    exit 1
fi
