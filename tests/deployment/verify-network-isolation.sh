#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
# BorgStack Network Isolation Verification Script
# ════════════════════════════════════════════════════════════════════════════
# Purpose: Validates Docker network configuration for security and isolation
# Story: 1.2 - Docker Network Configuration
#
# Tests Performed:
#   1. Network existence and configuration validation
#   2. Internal network isolation verification
#   3. Port exposure policy compliance
#
# Note: Service connectivity tests (DNS resolution, cross-network isolation)
#       will be performed in Story 6.1 when services are deployed.
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_test() {
    echo -e "\n${YELLOW}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_info() {
    echo -e "${YELLOW}ℹ️  INFO:${NC} $1"
}

# ════════════════════════════════════════════════════════════════════════════
# TEST 1: Docker Compose Configuration Syntax Validation
# ════════════════════════════════════════════════════════════════════════════
print_test "Validating docker-compose.yml syntax"

if docker compose config --quiet; then
    print_pass "docker-compose.yml syntax is valid"
else
    print_fail "docker-compose.yml syntax validation failed"
    exit 1
fi

# ════════════════════════════════════════════════════════════════════════════
# TEST 2: Network Existence Verification (Configuration-Level)
# ════════════════════════════════════════════════════════════════════════════
print_test "Verifying internal network exists with borgstack_internal name"

if grep -A 1 "^  internal:" docker-compose.yml | grep -q "name: borgstack_internal"; then
    print_pass "internal network defined with name borgstack_internal"
else
    print_fail "internal network not found or incorrectly named in docker-compose.yml"
fi

print_test "Verifying external network exists with borgstack_external name"

if grep -A 1 "^  external:" docker-compose.yml | grep -q "name: borgstack_external"; then
    print_pass "external network defined with name borgstack_external"
else
    print_fail "external network not found or incorrectly named in docker-compose.yml"
fi

# ════════════════════════════════════════════════════════════════════════════
# TEST 3: Internal Network Isolation Configuration
# ════════════════════════════════════════════════════════════════════════════
print_test "Verifying internal network has 'internal: true' setting"

if grep -A 5 "^  internal:" docker-compose.yml | grep -q "internal: true"; then
    print_pass "internal network has internal: true (network isolation enabled)"
else
    print_fail "internal network missing 'internal: true' setting - SECURITY RISK"
fi

# ════════════════════════════════════════════════════════════════════════════
# TEST 4: Network Driver Configuration
# ════════════════════════════════════════════════════════════════════════════
print_test "Verifying network driver configuration"

if grep -A 5 "^  internal:" docker-compose.yml | grep -q "driver: bridge"; then
    print_pass "internal network uses bridge driver"
else
    print_fail "internal network driver configuration incorrect"
fi

if grep -A 5 "^  external:" docker-compose.yml | grep -q "driver: bridge"; then
    print_pass "external network uses bridge driver"
else
    print_fail "external network driver configuration incorrect"
fi

# ════════════════════════════════════════════════════════════════════════════
# TEST 5: Port Exposure Policy Verification (Story 1.5 Enhanced)
# ════════════════════════════════════════════════════════════════════════════
print_test "Verifying ONLY Caddy exposes ports 80/443 (single entry point architecture)"

# Get all services that expose ports (using awk to parse docker-compose.yml)
SERVICES_WITH_PORTS=$(awk '/^  [a-z_-]+:/{service=$1} /^    ports:/{print service}' docker-compose.yml | sed 's/://g' | sort -u || true)

if [ -z "$SERVICES_WITH_PORTS" ]; then
    # No services expose ports yet (before Story 1.5)
    print_pass "No port exposure in base configuration (services not yet implemented)"
elif [ "$SERVICES_WITH_PORTS" = "caddy" ]; then
    # Only Caddy exposes ports (Story 1.5+)
    # Verify it's exposing exactly ports 80 and 443
    if grep -A 10 "^  caddy:" docker-compose.yml | grep -q '"80:80"' && \
       grep -A 10 "^  caddy:" docker-compose.yml | grep -q '"443:443"'; then
        print_pass "ONLY Caddy exposes ports 80/443 (correct single entry point architecture)"
    else
        print_fail "Caddy does not expose required ports 80 and 443"
    fi
else
    # Multiple services expose ports - SECURITY VIOLATION
    print_fail "Unauthorized port exposure detected - services other than Caddy expose ports: $SERVICES_WITH_PORTS"
    print_info "Only Caddy should expose ports to host (80/443). All other services must be internal."
fi

# ════════════════════════════════════════════════════════════════════════════
# TEST 6: Network Naming Convention Compliance
# ════════════════════════════════════════════════════════════════════════════
print_test "Verifying network naming follows Docker Compose best practices"

# Check that network keys are short names (internal/external) but 'name:' field has borgstack_ prefix
# This is the industry standard: Docker Compose prepends project name automatically
INTERNAL_NAME=$(grep -A 1 "^  internal:" docker-compose.yml | grep "name:" | awk '{print $2}' || echo "")
EXTERNAL_NAME=$(grep -A 1 "^  external:" docker-compose.yml | grep "name:" | awk '{print $2}' || echo "")

if [ "$INTERNAL_NAME" = "borgstack_internal" ] && [ "$EXTERNAL_NAME" = "borgstack_external" ]; then
    print_pass "Networks follow Docker Compose naming convention (short keys, full names in 'name:' field)"
else
    print_fail "Network naming incorrect. Expected: internal->borgstack_internal, external->borgstack_external"
    echo "  Found: internal->$INTERNAL_NAME, external->$EXTERNAL_NAME"
fi

# ════════════════════════════════════════════════════════════════════════════
# Deferred Tests (To Be Implemented in Future Stories)
# ════════════════════════════════════════════════════════════════════════════
print_info "DEFERRED TESTS (Story 6.1 - Integration Testing):"
print_info "  - Service DNS resolution testing (requires deployed services)"
print_info "  - Cross-network isolation verification (requires running containers)"
print_info "  - Database accessibility testing (requires PostgreSQL, MongoDB, Redis)"
print_info "  - Multi-network connectivity testing (requires application services)"

# ════════════════════════════════════════════════════════════════════════════
# Test Summary
# ════════════════════════════════════════════════════════════════════════════
echo ""
echo "════════════════════════════════════════════════════════════════════════════"
echo "Test Summary"
echo "════════════════════════════════════════════════════════════════════════════"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "════════════════════════════════════════════════════════════════════════════"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All network isolation tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Please review the output above.${NC}"
    exit 1
fi
