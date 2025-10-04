#!/usr/bin/env bash
#
# Directus Deployment Verification Test
# Tests all aspects of Directus deployment for Story 4.1
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

# Helper functions
log_test() {
    echo -e "${YELLOW}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

# Load environment variables
if [ -f .env ]; then
    # shellcheck disable=SC1091
    source .env
else
    log_fail ".env file not found"
    exit 1
fi

echo "=========================================="
echo "Directus Deployment Verification Tests"
echo "=========================================="
echo ""

# Setup: Start Directus and dependencies
echo "Starting Directus and dependencies..."
docker compose up -d postgresql redis directus
echo "Waiting for containers to be healthy..."
sleep 15
echo ""

# Test 1: Verify Directus container is running
log_test "Test 1: Verifying Directus container is running"
if docker compose ps directus | grep -q "Up"; then
    log_pass "Directus container is running"
else
    log_fail "Directus container is not running"
fi

# Test 2: Verify correct image version
log_test "Test 2: Verifying Directus image version"
if docker compose ps directus | grep -q "directus/directus:11"; then
    log_pass "Directus image version is correct (directus/directus:11)"
else
    log_fail "Directus image version is incorrect"
fi

# Test 3: Verify health check is passing
log_test "Test 3: Verifying Directus health check status"
if docker compose ps directus | grep -q "healthy"; then
    log_pass "Directus health check is passing"
else
    log_fail "Directus health check is not healthy"
fi

# Test 4: Verify database connection by checking logs
log_test "Test 4: Verifying database connection and migrations"
if docker compose logs directus 2>&1 | grep -qi "database.*connect\|migrations.*complete\|knex.*migrat"; then
    log_pass "Database connection established and migrations completed"
else
    log_fail "Database connection or migrations failed - check logs"
fi

# Test 5: Verify Redis connection by checking cache initialization
log_test "Test 5: Verifying Redis cache connection"
if docker compose logs directus 2>&1 | grep -qi "redis.*connect\|cache.*init\|cache.*enabled"; then
    log_pass "Redis connection established and cache initialized"
else
    log_fail "Redis connection or cache initialization failed - check logs"
fi

# Test 6: Verify local storage configuration
log_test "Test 6: Verifying local storage is configured"
if docker compose exec directus env | grep -q "STORAGE_LOCATIONS=local"; then
    log_pass "Local storage is configured (STORAGE_LOCATIONS=local)"
else
    log_fail "Local storage is not configured correctly"
fi

# Test 7: Verify web UI accessibility
log_test "Test 7: Verifying Directus web UI accessibility"
if [ -n "${DIRECTUS_HOST}" ]; then
    # Check if we can reach the admin login page (will fail if DNS/SSL not configured, which is OK for dev)
    if curl -f -k --max-time 5 "https://${DIRECTUS_HOST}/admin/login" &>/dev/null || \
       curl -f --max-time 5 "http://localhost:8055/admin/login" &>/dev/null; then
        log_pass "Directus web UI is accessible"
    else
        log_fail "Directus web UI is not accessible (check Caddy/DNS configuration)"
    fi
else
    log_fail "DIRECTUS_HOST not set in .env"
fi

# Test 8: Verify server health endpoint
log_test "Test 8: Verifying Directus /server/health endpoint"
if docker compose exec directus wget --quiet --tries=1 --spider http://localhost:8055/server/health; then
    log_pass "Directus health endpoint is accessible"
else
    log_fail "Directus health endpoint is not accessible"
fi

# Test 9: Verify REST API ping endpoint
log_test "Test 9: Verifying Directus /server/ping endpoint"
if docker compose exec directus wget --quiet --tries=1 --output-document=- http://localhost:8055/server/ping 2>/dev/null | grep -q "pong"; then
    log_pass "Directus ping endpoint is working"
else
    log_fail "Directus ping endpoint is not working"
fi

# Test 10: Verify GraphQL introspection endpoint
log_test "Test 10: Verifying GraphQL endpoint is accessible"
if docker compose exec directus wget --quiet --tries=1 --spider http://localhost:8055/graphql; then
    log_pass "GraphQL endpoint is accessible"
else
    log_fail "GraphQL endpoint is not accessible"
fi

# Test 11: Verify WebSocket endpoint availability
log_test "Test 11: Verifying WebSocket configuration"
if docker compose exec directus env | grep -q "WEBSOCKETS_ENABLED=true"; then
    log_pass "WebSocket support is enabled"
else
    log_fail "WebSocket support is not enabled"
fi

# Test 12: Verify Directus is on borgstack_internal network
log_test "Test 12: Verifying Directus is on borgstack_internal network"
if docker compose ps directus -q | xargs docker inspect --format '{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' | grep -q "$(docker network inspect borgstack_internal -f '{{.Id}}')"; then
    log_pass "Directus is connected to borgstack_internal network"
else
    log_fail "Directus is not connected to borgstack_internal network"
fi

# Test 13: Verify Directus is on borgstack_external network
log_test "Test 13: Verifying Directus is on borgstack_external network"
if docker compose ps directus -q | xargs docker inspect --format '{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' | grep -q "$(docker network inspect borgstack_external -f '{{.Id}}')"; then
    log_pass "Directus is connected to borgstack_external network"
else
    log_fail "Directus is not connected to borgstack_external network"
fi

# Test 14: Verify borgstack_directus_uploads volume exists
log_test "Test 14: Verifying borgstack_directus_uploads volume exists"
if docker volume ls | grep -q "borgstack_directus_uploads"; then
    log_pass "Volume borgstack_directus_uploads exists"
else
    log_fail "Volume borgstack_directus_uploads does not exist"
fi

# Test 15: Verify volume is mounted correctly
log_test "Test 15: Verifying borgstack_directus_uploads is mounted"
if docker compose exec directus test -d /directus/uploads; then
    log_pass "Volume is mounted at /directus/uploads"
else
    log_fail "Volume is not mounted at /directus/uploads"
fi

# Test 16: Verify no port exposure to host (production security requirement)
log_test "Test 16: Verifying no port exposure to host (security check)"
if docker compose ps directus | grep -q "8055->"; then
    log_fail "Directus has port 8055 exposed to host (security violation)"
else
    log_pass "Directus has no port exposure to host (security requirement met)"
fi

# Test 17: Verify database environment variables are set
log_test "Test 17: Verifying database environment variables"
if docker compose exec directus env | grep -q "DB_CLIENT=pg" && \
   docker compose exec directus env | grep -q "DB_HOST=postgresql" && \
   docker compose exec directus env | grep -q "DB_DATABASE=directus_db"; then
    log_pass "Database environment variables are configured correctly"
else
    log_fail "Database environment variables are not configured correctly"
fi

# Test 18: Verify Redis environment variables are set
log_test "Test 18: Verifying Redis environment variables"
if docker compose exec directus env | grep -q "REDIS_HOST=redis" && \
   docker compose exec directus env | grep -q "CACHE_ENABLED=true" && \
   docker compose exec directus env | grep -q "CACHE_STORE=redis"; then
    log_pass "Redis environment variables are configured correctly"
else
    log_fail "Redis environment variables are not configured correctly"
fi

# Test 19: Verify Directus depends on PostgreSQL
log_test "Test 19: Verifying Directus depends on PostgreSQL"
if docker compose config | grep -A 10 "directus:" | grep -q "postgresql:"; then
    log_pass "Directus has PostgreSQL dependency configured"
else
    log_fail "Directus does not have PostgreSQL dependency configured"
fi

# Test 20: Verify Directus depends on Redis
log_test "Test 20: Verifying Directus depends on Redis"
if docker compose config | grep -A 10 "directus:" | grep -q "redis:"; then
    log_pass "Directus has Redis dependency configured"
else
    log_fail "Directus does not have Redis dependency configured"
fi

# Test 21: Verify admin authentication (AC4 - Admin user and role management)
log_test "Test 21: Verifying admin authentication (AC4)"
if [ -n "${DIRECTUS_ADMIN_EMAIL:-}" ] && [ -n "${DIRECTUS_ADMIN_PASSWORD:-}" ]; then
    # Authenticate with admin credentials and get access token
    AUTH_RESPONSE=$(docker compose exec -T directus wget --quiet --output-document=- \
        --header="Content-Type: application/json" \
        --post-data="{\"email\":\"${DIRECTUS_ADMIN_EMAIL}\",\"password\":\"${DIRECTUS_ADMIN_PASSWORD}\"}" \
        http://localhost:8055/auth/login 2>/dev/null || echo "")

    if echo "${AUTH_RESPONSE}" | grep -q "access_token"; then
        log_pass "Admin authentication successful (AC4 validated)"
        # Extract access token for subsequent tests
        ACCESS_TOKEN=$(echo "${AUTH_RESPONSE}" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    else
        log_fail "Admin authentication failed (AC4 not validated)"
        ACCESS_TOKEN=""
    fi
else
    log_fail "DIRECTUS_ADMIN_EMAIL or DIRECTUS_ADMIN_PASSWORD not set in .env"
    ACCESS_TOKEN=""
fi

# Test 22: Verify collection creation capability (AC5 - Content models and collections)
log_test "Test 22: Verifying collection creation (AC5 - Part 1)"
if [ -n "${ACCESS_TOKEN}" ]; then
    # Create a test collection
    COLLECTION_NAME="test_blog_posts_$(date +%s)"
    CREATE_COLLECTION_RESPONSE=$(docker compose exec -T directus wget --quiet --output-document=- \
        --header="Content-Type: application/json" \
        --header="Authorization: Bearer ${ACCESS_TOKEN}" \
        --post-data="{\"collection\":\"${COLLECTION_NAME}\",\"meta\":{\"singleton\":false,\"icon\":\"article\"},\"schema\":{\"name\":\"${COLLECTION_NAME}\"}}" \
        http://localhost:8055/collections 2>/dev/null || echo "")

    if echo "${CREATE_COLLECTION_RESPONSE}" | grep -q "\"collection\":\"${COLLECTION_NAME}\""; then
        log_pass "Collection creation successful (AC5 - Part 1 validated)"
    else
        log_fail "Collection creation failed (AC5 - Part 1 not validated)"
        COLLECTION_NAME=""
    fi
else
    log_fail "Skipping collection creation test (no access token from Test 21)"
    COLLECTION_NAME=""
fi

# Test 23: Verify field creation in collection (AC5 - Content models)
log_test "Test 23: Verifying field creation in collection (AC5 - Part 2)"
if [ -n "${ACCESS_TOKEN}" ] && [ -n "${COLLECTION_NAME}" ]; then
    # Create a title field in the test collection
    CREATE_FIELD_RESPONSE=$(docker compose exec -T directus wget --quiet --output-document=- \
        --header="Content-Type: application/json" \
        --header="Authorization: Bearer ${ACCESS_TOKEN}" \
        --post-data="{\"field\":\"title\",\"type\":\"string\",\"meta\":{\"interface\":\"input\",\"required\":true},\"schema\":{\"is_nullable\":false}}" \
        "http://localhost:8055/fields/${COLLECTION_NAME}" 2>/dev/null || echo "")

    if echo "${CREATE_FIELD_RESPONSE}" | grep -q "\"field\":\"title\""; then
        log_pass "Field creation successful (AC5 - Part 2 validated)"
    else
        log_fail "Field creation failed (AC5 - Part 2 not validated)"
    fi
else
    log_fail "Skipping field creation test (no access token or collection from previous tests)"
fi

# Test 24: Verify content item creation (AC5 - Content CRUD)
log_test "Test 24: Verifying content item creation (AC5 - Part 3)"
if [ -n "${ACCESS_TOKEN}" ] && [ -n "${COLLECTION_NAME}" ]; then
    # Create a test item in the collection
    CREATE_ITEM_RESPONSE=$(docker compose exec -T directus wget --quiet --output-document=- \
        --header="Content-Type: application/json" \
        --header="Authorization: Bearer ${ACCESS_TOKEN}" \
        --post-data="{\"title\":\"Test Blog Post for QA Verification\"}" \
        "http://localhost:8055/items/${COLLECTION_NAME}" 2>/dev/null || echo "")

    if echo "${CREATE_ITEM_RESPONSE}" | grep -q "\"title\":\"Test Blog Post for QA Verification\""; then
        log_pass "Content item creation successful (AC5 - Part 3 validated)"
        # Extract item ID for retrieval test
        ITEM_ID=$(echo "${CREATE_ITEM_RESPONSE}" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    else
        log_fail "Content item creation failed (AC5 - Part 3 not validated)"
        ITEM_ID=""
    fi
else
    log_fail "Skipping content creation test (no access token or collection from previous tests)"
    ITEM_ID=""
fi

# Test 25: Verify content retrieval via REST API (AC5 - Content delivery)
log_test "Test 25: Verifying content retrieval via REST API (AC5 - Part 4)"
if [ -n "${ACCESS_TOKEN}" ] && [ -n "${COLLECTION_NAME}" ] && [ -n "${ITEM_ID}" ]; then
    # Retrieve the created item
    GET_ITEM_RESPONSE=$(docker compose exec -T directus wget --quiet --output-document=- \
        --header="Authorization: Bearer ${ACCESS_TOKEN}" \
        "http://localhost:8055/items/${COLLECTION_NAME}/${ITEM_ID}" 2>/dev/null || echo "")

    if echo "${GET_ITEM_RESPONSE}" | grep -q "\"title\":\"Test Blog Post for QA Verification\""; then
        log_pass "Content retrieval successful (AC5 - Part 4 validated)"
    else
        log_fail "Content retrieval failed (AC5 - Part 4 not validated)"
    fi
else
    log_fail "Skipping content retrieval test (no access token, collection, or item ID from previous tests)"
fi

# Test 26: Verify role management endpoint access (AC4 - Role management)
log_test "Test 26: Verifying role management endpoint (AC4 - Part 2)"
if [ -n "${ACCESS_TOKEN}" ]; then
    # Check if admin can access roles endpoint
    ROLES_RESPONSE=$(docker compose exec -T directus wget --quiet --output-document=- \
        --header="Authorization: Bearer ${ACCESS_TOKEN}" \
        http://localhost:8055/roles 2>/dev/null || echo "")

    if echo "${ROLES_RESPONSE}" | grep -q "\"data\":\["; then
        log_pass "Role management endpoint accessible (AC4 - Part 2 validated)"
    else
        log_fail "Role management endpoint not accessible (AC4 - Part 2 not validated)"
    fi
else
    log_fail "Skipping role management test (no access token from Test 21)"
fi

# Cleanup: Delete test collection if created
if [ -n "${ACCESS_TOKEN}" ] && [ -n "${COLLECTION_NAME}" ]; then
    docker compose exec -T directus wget --quiet --output-document=- \
        --method=DELETE \
        --header="Authorization: Bearer ${ACCESS_TOKEN}" \
        "http://localhost:8055/collections/${COLLECTION_NAME}" 2>/dev/null >/dev/null || true
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Tests Passed:${NC} ${TESTS_PASSED}"
echo -e "${RED}Tests Failed:${NC} ${TESTS_FAILED}"
echo ""

if [ ${TESTS_FAILED} -eq 0 ]; then
    echo -e "${GREEN}✓ All Directus deployment tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the output above.${NC}"
    exit 1
fi
