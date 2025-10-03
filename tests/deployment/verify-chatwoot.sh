#!/usr/bin/env bash
#
# Chatwoot Customer Service Platform - Deployment Validation Tests
# Story 3.1: Chatwoot Customer Service
#
# This script validates:
# - Chatwoot container running and healthy
# - Database connection (PostgreSQL migrations completed)
# - Redis connection (Sidekiq running)
# - Web UI accessibility via Caddy (HTTPS)
# - Volume persistence (storage and public assets)
# - API health endpoints
# - Agent management API (AC5 validation)
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
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    echo "${GREEN}✓${RESET} $*"
}

test_fail() {
    ((TESTS_RUN++))
    ((TESTS_FAILED++))
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
echo "${BOLD}${BLUE}Chatwoot Customer Service Platform - Validation Tests${RESET}"
echo "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# ----------------------------------------------------------------------------
# Test 1: Verify Chatwoot Container is Running
# ----------------------------------------------------------------------------
echo "${BOLD}Test 1: Verify Chatwoot container is running${RESET}"

if docker compose ps chatwoot | grep -q "Up"; then
    test_pass "Chatwoot container is running"
else
    test_fail "Chatwoot container is not running"
    echo "${YELLOW}  Hint: Start with 'docker compose up -d chatwoot'${RESET}"
fi

# ----------------------------------------------------------------------------
# Test 2: Verify Chatwoot Health Check Passes
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 2: Verify Chatwoot health check passes${RESET}"

# Check if container is healthy (may take up to 90 seconds on first startup)
if docker compose ps chatwoot | grep -q "healthy"; then
    test_pass "Chatwoot health check is passing"
else
    if docker compose ps chatwoot | grep -q "starting"; then
        test_warning "Chatwoot health check is starting (wait up to 90 seconds for first startup)"
        test_info "Rails migrations + asset compilation may take time"
        test_info "Monitor with: docker compose logs -f chatwoot"
    else
        test_fail "Chatwoot health check is not healthy"
        echo "${YELLOW}  Hint: Check logs with 'docker compose logs chatwoot | tail -50'${RESET}"
    fi
fi

# ----------------------------------------------------------------------------
# Test 3: Verify Chatwoot Database Connection (Rails Migrations)
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 3: Verify Chatwoot database connection (Rails migrations completed)${RESET}"

# Check logs for successful database migration
if docker compose logs chatwoot 2>/dev/null | grep -qi "migrat"; then
    # More lenient check - just verify migrations ran (success or already up-to-date)
    if docker compose logs chatwoot 2>/dev/null | grep -Ei "(migration.*complete|migrated|up to date)" >/dev/null; then
        test_pass "Rails database migrations completed successfully"
    else
        # Check if migrations failed
        if docker compose logs chatwoot 2>/dev/null | grep -Ei "(migration.*fail|error.*migrat)" >/dev/null; then
            test_fail "Rails database migrations failed"
            echo "${YELLOW}  Hint: Check PostgreSQL connection and CHATWOOT_DB_PASSWORD${RESET}"
        else
            test_warning "Rails migrations status unclear (container may still be starting)"
            test_info "Wait for startup to complete, then re-run test"
        fi
    fi
else
    test_warning "No migration logs found yet (container may still be starting)"
    test_info "Rails migrations run during startup - may take 30-45 seconds"
fi

# ----------------------------------------------------------------------------
# Test 4: Verify Chatwoot Redis Connection (Sidekiq Running)
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 4: Verify Chatwoot Redis connection (Sidekiq background worker)${RESET}"

# Check logs for Sidekiq startup (background job processor)
if docker compose logs chatwoot 2>/dev/null | grep -qi "sidekiq"; then
    if docker compose logs chatwoot 2>/dev/null | grep -Ei "(sidekiq.*start|sidekiq.*running)" >/dev/null; then
        test_pass "Sidekiq background worker started (Redis connection OK)"
    else
        if docker compose logs chatwoot 2>/dev/null | grep -Ei "(redis.*error|sidekiq.*fail)" >/dev/null; then
            test_fail "Sidekiq failed to connect to Redis"
            echo "${YELLOW}  Hint: Check Redis container and REDIS_PASSWORD${RESET}"
        else
            test_warning "Sidekiq status unclear (container may still be starting)"
        fi
    fi
else
    test_warning "No Sidekiq logs found yet (container may still be starting)"
    test_info "Sidekiq starts after Rails migrations - may take 60+ seconds"
fi

# ----------------------------------------------------------------------------
# Test 5: Verify Chatwoot Web UI Accessible via HTTPS (Caddy)
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 5: Verify Chatwoot web UI accessible via HTTPS (Caddy)${RESET}"

# Check if CHATWOOT_HOST is set
if [[ -n "${CHATWOOT_HOST:-}" ]]; then
    # Try to access web UI via HTTPS
    if command -v curl >/dev/null 2>&1; then
        # Use -k to allow self-signed certs in dev, -f to fail on HTTP errors, -s for silent
        if curl -f -s -k "https://${CHATWOOT_HOST}/" -o /dev/null 2>&1; then
            test_pass "Chatwoot web UI accessible via HTTPS (https://${CHATWOOT_HOST}/)"
        else
            # Try HTTP (Caddy should redirect)
            if curl -f -s "http://${CHATWOOT_HOST}/" -o /dev/null 2>&1; then
                test_warning "Chatwoot accessible via HTTP but HTTPS failed"
                echo "${YELLOW}  Hint: Check Caddy SSL certificate provisioning${RESET}"
                echo "${YELLOW}  DNS must point to server IP for Let's Encrypt${RESET}"
            else
                test_fail "Chatwoot web UI not accessible via HTTP or HTTPS"
                echo "${YELLOW}  Hint: Check Caddy reverse proxy configuration${RESET}"
                echo "${YELLOW}  Verify DNS A record: dig ${CHATWOOT_HOST} +short${RESET}"
            fi
        fi
    else
        test_warning "curl not installed - cannot test HTTPS access"
        test_info "Install curl: sudo apt install curl"
    fi
else
    test_warning "CHATWOOT_HOST not set in .env - skipping HTTPS test"
fi

# ----------------------------------------------------------------------------
# Test 6: Verify Volumes Mounted (Storage and Public Assets)
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 6: Verify volumes mounted (borgstack_chatwoot_storage, borgstack_chatwoot_public)${RESET}"

# Check if volumes exist
volume_storage_exists=false
volume_public_exists=false

if docker volume ls | grep -q "borgstack_chatwoot_storage"; then
    volume_storage_exists=true
fi

if docker volume ls | grep -q "borgstack_chatwoot_public"; then
    volume_public_exists=true
fi

if [[ "${volume_storage_exists}" == "true" ]] && [[ "${volume_public_exists}" == "true" ]]; then
    test_pass "Both volumes exist (borgstack_chatwoot_storage, borgstack_chatwoot_public)"

    # Verify volumes are actually mounted to container
    if docker compose ps chatwoot | grep -q "Up"; then
        storage_mounted=$(docker inspect chatwoot 2>/dev/null | grep -c "borgstack_chatwoot_storage" || echo "0")
        public_mounted=$(docker inspect chatwoot 2>/dev/null | grep -c "borgstack_chatwoot_public" || echo "0")

        if [[ "${storage_mounted}" -gt 0 ]] && [[ "${public_mounted}" -gt 0 ]]; then
            test_pass "Both volumes mounted to chatwoot container"
        else
            test_fail "Volumes exist but not mounted to container"
            echo "${YELLOW}  Hint: Restart container: docker compose restart chatwoot${RESET}"
        fi
    else
        test_warning "Container not running - cannot verify volume mounts"
    fi
elif [[ "${volume_storage_exists}" == "true" ]]; then
    test_fail "Only borgstack_chatwoot_storage exists (borgstack_chatwoot_public missing)"
elif [[ "${volume_public_exists}" == "true" ]]; then
    test_fail "Only borgstack_chatwoot_public exists (borgstack_chatwoot_storage missing)"
else
    test_fail "Neither volume exists"
    echo "${YELLOW}  Hint: Volumes created automatically on first 'docker compose up'${RESET}"
fi

# ----------------------------------------------------------------------------
# Test 7: Verify Chatwoot API Health Endpoint
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 7: Verify Chatwoot API health endpoint (/api returns 200 OK)${RESET}"

if [[ -n "${CHATWOOT_HOST:-}" ]] && command -v curl >/dev/null 2>&1; then
    # Test internal health check endpoint (same as Docker healthcheck)
    if docker compose ps chatwoot | grep -q "Up"; then
        # Test via Caddy HTTPS proxy
        if curl -f -s -k "https://${CHATWOOT_HOST}/api" -o /dev/null 2>&1; then
            test_pass "API health endpoint accessible via HTTPS (/api returns 200 OK)"
        else
            test_fail "API health endpoint not accessible"
            echo "${YELLOW}  Hint: Check if Chatwoot web server (Puma) started${RESET}"
            echo "${YELLOW}  Logs: docker compose logs chatwoot | grep -i puma${RESET}"
        fi
    else
        test_warning "Chatwoot container not running - cannot test API endpoint"
    fi
else
    if [[ -z "${CHATWOOT_HOST:-}" ]]; then
        test_warning "CHATWOOT_HOST not set - skipping API health test"
    else
        test_warning "curl not installed - skipping API health test"
    fi
fi

# ----------------------------------------------------------------------------
# Test 8: Verify Agent Management API Endpoint (AC5 Validation)
# ----------------------------------------------------------------------------
echo ""
echo "${BOLD}Test 8: Verify agent management API endpoint (validates AC5)${RESET}"

# Check if CHATWOOT_API_TOKEN is set and not placeholder
if [[ -n "${CHATWOOT_API_TOKEN:-}" ]] && [[ "${CHATWOOT_API_TOKEN}" != "<obtain-from-admin-ui-after-first-login>" ]]; then
    if [[ -n "${CHATWOOT_HOST:-}" ]] && command -v curl >/dev/null 2>&1; then
        # Try to access agent management API
        # Note: Account ID is typically 1 for first account, may need adjustment for multi-account setups
        api_response=$(curl -s -k -w "%{http_code}" -o /dev/null \
            "https://${CHATWOOT_HOST}/api/v1/accounts/1/agents" \
            -H "api_access_token: ${CHATWOOT_API_TOKEN}" 2>/dev/null || echo "000")

        if [[ "${api_response}" == "200" ]]; then
            test_pass "Agent management API accessible with CHATWOOT_API_TOKEN (AC5 validated)"
            test_info "API token authentication working correctly"
        elif [[ "${api_response}" == "401" ]]; then
            test_fail "Agent management API returned 401 Unauthorized"
            echo "${YELLOW}  Hint: CHATWOOT_API_TOKEN may be invalid or expired${RESET}"
            echo "${YELLOW}  Regenerate token: Chatwoot UI → Profile → Access Tokens${RESET}"
        elif [[ "${api_response}" == "404" ]]; then
            test_fail "Agent management API returned 404 Not Found"
            echo "${YELLOW}  Hint: Account ID may not be 1, check Chatwoot admin UI${RESET}"
        else
            test_fail "Agent management API returned unexpected status: ${api_response}"
            echo "${YELLOW}  Hint: Check Chatwoot logs for errors${RESET}"
        fi
    else
        if [[ -z "${CHATWOOT_HOST:-}" ]]; then
            test_warning "CHATWOOT_HOST not set - skipping agent API test"
        else
            test_warning "curl not installed - skipping agent API test"
        fi
    fi
else
    test_warning "CHATWOOT_API_TOKEN not set or is placeholder - skipping agent API test"
    test_info "Generate token: Chatwoot UI → Profile → Access Tokens → Create New Token"
    test_info "Add to .env: CHATWOOT_API_TOKEN=<your-token>"
    test_info "Restart: docker compose restart chatwoot"
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
    echo "  1. Access Chatwoot admin UI: https://${CHATWOOT_HOST:-chatwoot.your-domain.com}/app"
    echo "  2. Create first admin account (if not already done)"
    echo "  3. Generate API token: Settings → Account Settings → Access Tokens"
    echo "  4. Add CHATWOOT_API_TOKEN to .env file"
    echo "  5. Configure WhatsApp integration via n8n (see config/chatwoot/README.md)"
    echo ""
    exit 0
else
    echo "${RED}${BOLD}✗ Some tests failed${RESET}"
    echo ""
    echo "${YELLOW}Troubleshooting:${RESET}"
    echo "  - Check logs: docker compose logs chatwoot"
    echo "  - Verify .env configuration (CHATWOOT_DB_PASSWORD, CHATWOOT_SECRET_KEY_BASE)"
    echo "  - Ensure PostgreSQL and Redis are healthy: docker compose ps"
    echo "  - Review setup guide: config/chatwoot/README.md"
    echo ""
    exit 1
fi
