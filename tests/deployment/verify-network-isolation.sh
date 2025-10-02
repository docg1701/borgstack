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
print_test "Verifying borgstack_internal network exists in configuration"

if grep -q "borgstack_internal:" docker-compose.yml; then
    print_pass "borgstack_internal network defined in docker-compose.yml"
else
    print_fail "borgstack_internal network not found in docker-compose.yml"
fi

print_test "Verifying borgstack_external network exists in configuration"

if grep -q "borgstack_external:" docker-compose.yml; then
    print_pass "borgstack_external network defined in docker-compose.yml"
else
    print_fail "borgstack_external network not found in docker-compose.yml"
fi

# ════════════════════════════════════════════════════════════════════════════
# TEST 3: Internal Network Isolation Configuration
# ════════════════════════════════════════════════════════════════════════════
print_test "Verifying borgstack_internal has 'internal: true' setting"

if grep -A 5 "borgstack_internal:" docker-compose.yml | grep -q "internal: true"; then
    print_pass "borgstack_internal has internal: true (network isolation enabled)"
else
    print_fail "borgstack_internal missing 'internal: true' setting - SECURITY RISK"
fi

# ════════════════════════════════════════════════════════════════════════════
# TEST 4: Network Driver Configuration
# ════════════════════════════════════════════════════════════════════════════
print_test "Verifying network driver configuration"

if grep -A 5 "borgstack_internal:" docker-compose.yml | grep -q "driver: bridge"; then
    print_pass "borgstack_internal uses bridge driver"
else
    print_fail "borgstack_internal driver configuration incorrect"
fi

if grep -A 5 "borgstack_external:" docker-compose.yml | grep -q "driver: bridge"; then
    print_pass "borgstack_external uses bridge driver"
else
    print_fail "borgstack_external driver configuration incorrect"
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
print_test "Verifying network naming follows 'borgstack_' prefix convention"

# Extract network names from networks section and check for non-borgstack_ prefixes
# Pattern: sed extracts from 'networks:' to next non-indented line, filters for network declarations
INVALID_NETWORKS=$(sed -n '/^networks:/,/^[^ ]/{/^  [a-z_-]\+:/p}' docker-compose.yml | sed 's/:.*//; s/^  //' | grep -v "^borgstack_" || true)

if [ -z "$INVALID_NETWORKS" ]; then
    print_pass "All networks follow 'borgstack_' naming convention"
else
    print_fail "Found networks not following 'borgstack_' prefix convention"
    echo "$INVALID_NETWORKS"
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
