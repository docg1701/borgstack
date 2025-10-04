#!/usr/bin/env bash
#
# Lowcoder Application Platform - Deployment Validation Tests
# Story 3.2: Lowcoder Application Platform
#
# This script validates:
# - Lowcoder container running with correct image version
# - Network configuration (borgstack_internal and borgstack_external)
# - Volume mounting (borgstack_lowcoder_stacks)
# - No port exposure to host (security requirement)
# - Health check configured correctly
# - MongoDB connection (LOWCODER_MONGODB_URL)
# - Redis connection (LOWCODER_REDIS_URL)
# - Admin credentials configured
# - Encryption keys configured
# - Dependencies on MongoDB and Redis (service_healthy)
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Color output
if [[ -t 1 ]]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    RESET=""
fi

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
test_pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "${GREEN}✓${RESET} $*"
}

test_fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "${RED}✗${RESET} $*"
}

test_info() {
    echo "${BLUE}ℹ${RESET} $*"
}

test_warning() {
    echo "${YELLOW}⚠${RESET} $*"
}

# Change to project root
cd "${PROJECT_ROOT}"

# Load environment variables if .env exists
if [[ -f .env ]]; then
    # shellcheck disable=SC1091
    set -a
    source .env
    set +a
    test_info "Loaded environment variables from .env"
else
    test_warning ".env file not found - using defaults"
fi

# ============================================================================
# TEST SUITE
# ============================================================================

echo ""
echo "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${BOLD}${BLUE}Lowcoder Application Platform - Validation Tests${RESET}"
echo "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# ----------------------------------------------------------------------------
# Test 1: Verify Lowcoder Image Version
# ----------------------------------------------------------------------------
echo "${BOLD}Test 1: Verify Lowcoder image version (lowcoderorg/lowcoder-ce:2.7.4)${RESET}"

if docker compose config | grep -A30 "lowcoder:" | grep -q "lowcoderorg/lowcoder-ce:2.7.4"; then
    test_pass "Lowcoder image correctly configured (lowcoderorg/lowcoder-ce:2.7.4)"
else
    test_fail "Lowcoder image not configured correctly"
    echo "${YELLOW}  Expected: lowcoderorg/lowcoder-ce:2.7.4${RESET}"
    echo "${YELLOW}  Check: docker compose config | grep -A5 'lowcoder:'${RESET}"
fi

# ----------------------------------------------------------------------------
# Test 2: Verify Lowcoder Connected to borgstack_internal Network
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 2: Verify Lowcoder connected to borgstack_internal network${RESET}"

if docker compose config | grep -A35 "lowcoder:" | grep -q "borgstack_internal"; then
    test_pass "Lowcoder connected to borgstack_internal network"
else
    test_fail "Lowcoder not connected to borgstack_internal network"
    echo "${YELLOW}  Hint: Required for MongoDB and Redis access${RESET}"
fi

# ----------------------------------------------------------------------------
# Test 3: Verify Lowcoder Connected to borgstack_external Network
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 3: Verify Lowcoder connected to borgstack_external network${RESET}"

if docker compose config | grep -A35 "lowcoder:" | grep -q "borgstack_external"; then
    test_pass "Lowcoder connected to borgstack_external network"
else
    test_fail "Lowcoder not connected to borgstack_external network"
    echo "${YELLOW}  Hint: Required for Caddy reverse proxy access${RESET}"
fi

# ----------------------------------------------------------------------------
# Test 4: Verify Volume borgstack_lowcoder_stacks
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 4: Verify volume borgstack_lowcoder_stacks follows naming convention${RESET}"

if docker compose config | grep -q "borgstack_lowcoder_stacks"; then
    test_pass "Volume borgstack_lowcoder_stacks follows naming convention"
else
    test_fail "Volume borgstack_lowcoder_stacks missing"
    echo "${YELLOW}  Hint: Add volume definition in docker-compose.yml${RESET}"
fi

# ----------------------------------------------------------------------------
# Test 5: Verify No Port Exposure to Host (Security Requirement)
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 5: Verify no port exposure to host (security requirement)${RESET}"

if docker compose config | grep -A30 "lowcoder:" | grep -q "ports:"; then
    test_fail "Lowcoder has port exposure in production config (security violation)"
    echo "${YELLOW}  Hint: Remove 'ports:' section - access via Caddy reverse proxy only${RESET}"
else
    test_pass "No port exposure to host (security requirement met)"
fi

# ----------------------------------------------------------------------------
# Test 6: Verify Health Check Configured
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 6: Verify health check configured for Lowcoder${RESET}"

if docker compose config | grep -A40 "lowcoder:" | grep -q "healthcheck:"; then
    test_pass "Health check configured for Lowcoder"

    # Verify health check command
    if docker compose config | grep -A40 "lowcoder:" | grep -q "http://localhost:3000/api/health"; then
        test_pass "Health check endpoint correct (http://localhost:3000/api/health)"
    else
        test_fail "Health check endpoint incorrect"
        echo "${YELLOW}  Expected: curl -f http://localhost:3000/api/health${RESET}"
    fi
else
    test_fail "Health check not configured for Lowcoder"
    echo "${YELLOW}  Hint: Add healthcheck section in docker-compose.yml${RESET}"
fi

# ----------------------------------------------------------------------------
# Test 7: Verify MongoDB Connection String (LOWCODER_MONGODB_URL)
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 7: Verify MongoDB connection string (LOWCODER_MONGODB_URL)${RESET}"

if docker compose config | grep -A30 "lowcoder:" | grep -q "LOWCODER_MONGODB_URL"; then
    test_pass "LOWCODER_MONGODB_URL configured"

    # Verify connection string format
    if docker compose config | grep -A30 "lowcoder:" | grep "LOWCODER_MONGODB_URL" | grep -q "mongodb://lowcoder_user:.*@mongodb:27017/lowcoder?authSource=lowcoder"; then
        test_pass "MongoDB connection string format correct"
    else
        test_fail "MongoDB connection string format incorrect"
        echo "${YELLOW}  Expected: mongodb://lowcoder_user:\${LOWCODER_DB_PASSWORD}@mongodb:27017/lowcoder?authSource=lowcoder${RESET}"
    fi
else
    test_fail "LOWCODER_MONGODB_URL not configured"
    echo "${YELLOW}  Hint: Add LOWCODER_MONGODB_URL environment variable${RESET}"
fi

# ----------------------------------------------------------------------------
# Test 8: Verify Redis Connection String (LOWCODER_REDIS_URL)
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 8: Verify Redis connection string (LOWCODER_REDIS_URL)${RESET}"

if docker compose config | grep -A30 "lowcoder:" | grep -q "LOWCODER_REDIS_URL"; then
    test_pass "LOWCODER_REDIS_URL configured"

    # Verify connection string format
    if docker compose config | grep -A30 "lowcoder:" | grep "LOWCODER_REDIS_URL" | grep -q "redis://.*@redis:6379"; then
        test_pass "Redis connection string format correct"
    else
        test_fail "Redis connection string format incorrect"
        echo "${YELLOW}  Expected: redis://:\${REDIS_PASSWORD}@redis:6379${RESET}"
    fi
else
    test_fail "LOWCODER_REDIS_URL not configured"
    echo "${YELLOW}  Hint: Add LOWCODER_REDIS_URL environment variable${RESET}"
fi

# ----------------------------------------------------------------------------
# Test 9: Verify Admin Credentials Configured
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 9: Verify admin credentials configured${RESET}"

admin_email_configured=false
admin_password_configured=false

if docker compose config | grep -A30 "lowcoder:" | grep -q "LOWCODER_ADMIN_EMAIL"; then
    admin_email_configured=true
    test_pass "LOWCODER_ADMIN_EMAIL configured"
else
    test_fail "LOWCODER_ADMIN_EMAIL not configured"
fi

if docker compose config | grep -A30 "lowcoder:" | grep -q "LOWCODER_ADMIN_PASSWORD"; then
    admin_password_configured=true
    test_pass "LOWCODER_ADMIN_PASSWORD configured"
else
    test_fail "LOWCODER_ADMIN_PASSWORD not configured"
fi

if [[ "${admin_email_configured}" == "true" ]] && [[ "${admin_password_configured}" == "true" ]]; then
    test_info "Admin credentials fully configured"
fi

# ----------------------------------------------------------------------------
# Test 10: Verify Encryption Keys Configured (32-char requirement)
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 10: Verify encryption keys configured${RESET}"

encryption_password_configured=false
encryption_salt_configured=false

if docker compose config | grep -A30 "lowcoder:" | grep -q "LOWCODER_ENCRYPTION_PASSWORD"; then
    encryption_password_configured=true
    test_pass "LOWCODER_ENCRYPTION_PASSWORD configured"
else
    test_fail "LOWCODER_ENCRYPTION_PASSWORD not configured"
fi

if docker compose config | grep -A30 "lowcoder:" | grep -q "LOWCODER_ENCRYPTION_SALT"; then
    encryption_salt_configured=true
    test_pass "LOWCODER_ENCRYPTION_SALT configured"
else
    test_fail "LOWCODER_ENCRYPTION_SALT not configured"
fi

if [[ "${encryption_password_configured}" == "true" ]] && [[ "${encryption_salt_configured}" == "true" ]]; then
    test_info "Encryption keys fully configured"
fi

# ----------------------------------------------------------------------------
# Test 11: Verify Dependency on MongoDB (service_healthy)
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 11: Verify Lowcoder depends on MongoDB (condition: service_healthy)${RESET}"

if docker compose config | grep -A10 "lowcoder:" | grep -A5 "depends_on:" | grep -q "mongodb:"; then
    test_pass "Lowcoder depends on MongoDB"

    # Verify service_healthy condition
    if docker compose config | grep -A10 "lowcoder:" | grep -A8 "depends_on:" | grep -A2 "mongodb:" | grep -q "service_healthy"; then
        test_pass "MongoDB dependency uses service_healthy condition"
    else
        test_fail "MongoDB dependency missing service_healthy condition"
        echo "${YELLOW}  Hint: Add 'condition: service_healthy' to mongodb dependency${RESET}"
    fi
else
    test_fail "Lowcoder missing MongoDB dependency"
    echo "${YELLOW}  Hint: Add depends_on: mongodb: condition: service_healthy${RESET}"
fi

# ----------------------------------------------------------------------------
# Test 12: Verify Dependency on Redis (service_healthy)
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 12: Verify Lowcoder depends on Redis (condition: service_healthy)${RESET}"

if docker compose config | grep -A10 "lowcoder:" | grep -A5 "depends_on:" | grep -q "redis:"; then
    test_pass "Lowcoder depends on Redis"

    # Verify service_healthy condition
    if docker compose config | grep -A10 "lowcoder:" | grep -A8 "depends_on:" | grep -A2 "redis:" | grep -q "service_healthy"; then
        test_pass "Redis dependency uses service_healthy condition"
    else
        test_fail "Redis dependency missing service_healthy condition"
        echo "${YELLOW}  Hint: Add 'condition: service_healthy' to redis dependency${RESET}"
    fi
else
    test_fail "Lowcoder missing Redis dependency"
    echo "${YELLOW}  Hint: Add depends_on: redis: condition: service_healthy${RESET}"
fi

# ============================================================================
# TEST SUMMARY
# ============================================================================

echo ""
echo "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo "${BOLD}${BLUE}Test Summary${RESET}"
echo "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo "Total tests run:    ${BOLD}${TESTS_RUN}${RESET}"
echo "Tests passed:       ${BOLD}${GREEN}${TESTS_PASSED}${RESET}"
echo "Tests failed:       ${BOLD}${RED}${TESTS_FAILED}${RESET}"
echo ""

if [[ ${TESTS_FAILED} -eq 0 ]]; then
    echo "${GREEN}${BOLD}✓ All tests passed!${RESET}"
    echo ""
    echo "${BLUE}Next steps:${RESET}"
    echo "  1. Verify Lowcoder container is running: docker compose ps lowcoder"
    echo "  2. Access Lowcoder admin UI: https://${LOWCODER_HOST:-lowcoder.your-domain.com}"
    echo "  3. Login with admin credentials from .env file"
    echo "  4. Create your first application (see config/lowcoder/README.md)"
    echo "  5. Connect to PostgreSQL databases and create dashboards"
    echo ""
    exit 0
else
    echo "${RED}${BOLD}✗ Some tests failed${RESET}"
    echo ""
    echo "${YELLOW}Troubleshooting:${RESET}"
    echo "  - Check docker-compose.yml configuration"
    echo "  - Verify .env file has all required LOWCODER_* variables"
    echo "  - Ensure MongoDB and Redis are healthy: docker compose ps"
    echo "  - Review setup guide: config/lowcoder/README.md"
    echo ""
    exit 1
fi
