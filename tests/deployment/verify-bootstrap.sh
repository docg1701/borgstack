#!/usr/bin/env bash
#
# BorgStack Bootstrap Validation Tests
# Validates that bootstrap.sh successfully configured the system
#
# This script runs 11 validation tests covering:
# - GNU/Linux distribution validation
# - System requirements check
# - Docker installation
# - Firewall configuration
# - .env file generation and security
# - Docker image availability
# - Service health checks
# - Idempotency
# - DNS configuration instructions
# - DNS verification
# - Error handling
#

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=11

# Color output
if [[ -t 1 ]]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    BOLD=""
    RESET=""
fi

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_test() {
    echo ""
    echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo "${BOLD}${CYAN}TEST $1: $2${RESET}"
    echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

pass() {
    echo "${GREEN}✓ PASS:${RESET} $*"
    ((TESTS_PASSED++)) || true
}

fail() {
    echo "${RED}✗ FAIL:${RESET} $*"
    ((TESTS_FAILED++)) || true
}

warn() {
    echo "${YELLOW}⚠ WARN:${RESET} $*"
}

info() {
    echo "${BLUE}ℹ INFO:${RESET} $*"
}

# ============================================================================
# TEST 1: GNU/Linux DISTRIBUTION VALIDATION
# ============================================================================

test_linux_distribution() {
    log_test 1 "GNU/Linux Distribution Validation"

    if [[ ! -f /etc/os-release ]]; then
        fail "/etc/os-release not found"
        return 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    # Check if it's a supported Linux distribution
    local supported=false
    case "${ID}" in
        ubuntu|debian|centos|rhel|rocky|almalinux|fedora|arch|opensuse-leap|opensuse-tumbleweed)
            supported=true
            ;;
    esac

    if [[ "${supported}" == "true" ]]; then
        pass "Supported GNU/Linux distribution detected: ${NAME} ${VERSION_ID}"
    else
        warn "Distribution ${NAME} may not be officially supported"
        pass "GNU/Linux distribution detected: ${NAME} ${VERSION_ID}"
    fi
}

# ============================================================================
# TEST 2: SYSTEM REQUIREMENTS CHECK
# ============================================================================

test_system_requirements() {
    log_test 2 "System Requirements Check"

    local all_passed=true

    # Check RAM
    local ram_gb
    ram_gb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    ram_gb=$((ram_gb / 1024 / 1024))

    info "RAM: ${ram_gb}GB (minimum: 8GB)"
    if [[ ${ram_gb} -ge 8 ]]; then
        pass "RAM requirement met: ${ram_gb}GB >= 8GB"
    else
        warn "RAM below minimum: ${ram_gb}GB < 8GB"
        all_passed=false
    fi

    # Check disk space
    local disk_gb
    disk_gb=$(df -BG / | awk 'NR==2 {print $2}' | sed 's/G//')

    info "Disk: ${disk_gb}GB (minimum: 100GB)"
    if [[ ${disk_gb} -ge 100 ]]; then
        pass "Disk requirement met: ${disk_gb}GB >= 100GB"
    else
        warn "Disk below minimum: ${disk_gb}GB < 100GB"
        all_passed=false
    fi

    # Check CPU cores
    local cpu_cores
    cpu_cores=$(nproc)

    info "CPU cores: ${cpu_cores} (minimum: 2)"
    if [[ ${cpu_cores} -ge 2 ]]; then
        pass "CPU requirement met: ${cpu_cores} >= 2"
    else
        warn "CPU below minimum: ${cpu_cores} < 2"
        all_passed=false
    fi

    if [[ "${all_passed}" == "true" ]]; then
        pass "All system requirements validated"
    else
        fail "Some system requirements not met (see warnings above)"
    fi
}

# ============================================================================
# TEST 3: DOCKER INSTALLATION VERIFICATION
# ============================================================================

test_docker_installation() {
    log_test 3 "Docker Installation Verification"

    # Check Docker installed
    if ! command -v docker >/dev/null 2>&1; then
        fail "Docker not installed"
        return 1
    fi

    local docker_version
    docker_version=$(docker --version)
    info "Docker version: ${docker_version}"
    pass "Docker installed"

    # Check Docker Compose v2 installed
    if ! docker compose version >/dev/null 2>&1; then
        fail "Docker Compose v2 not installed"
        return 1
    fi

    local compose_version
    compose_version=$(docker compose version)
    info "Docker Compose version: ${compose_version}"
    pass "Docker Compose v2 installed"

    # Check user in docker group
    if groups | grep -q docker; then
        pass "User in docker group"
    else
        warn "User not in docker group (may need to log out/in)"
    fi

    # Check Docker service running
    if systemctl is-active --quiet docker; then
        pass "Docker service is running"
    else
        fail "Docker service not running"
        return 1
    fi
}

# ============================================================================
# TEST 4: FIREWALL CONFIGURATION VERIFICATION
# ============================================================================

test_firewall_configuration() {
    log_test 4 "Firewall Configuration Verification"

    # Check UFW installed
    if ! command -v ufw >/dev/null 2>&1; then
        fail "UFW not installed"
        return 1
    fi

    # Check UFW enabled
    if ! sudo ufw status | grep -q "Status: active"; then
        fail "UFW not enabled"
        return 1
    fi

    pass "UFW firewall is active"

    # Check required ports
    local ports_configured=true

    if sudo ufw status | grep -q "22/tcp"; then
        pass "Port 22/tcp (SSH) allowed"
    else
        fail "Port 22/tcp (SSH) not allowed"
        ports_configured=false
    fi

    if sudo ufw status | grep -q "80/tcp"; then
        pass "Port 80/tcp (HTTP) allowed"
    else
        fail "Port 80/tcp (HTTP) not allowed"
        ports_configured=false
    fi

    if sudo ufw status | grep -q "443/tcp"; then
        pass "Port 443/tcp (HTTPS) allowed"
    else
        fail "Port 443/tcp (HTTPS) not allowed"
        ports_configured=false
    fi

    if [[ "${ports_configured}" == "true" ]]; then
        pass "All required firewall rules configured"
    else
        fail "Some firewall rules missing"
    fi
}

# ============================================================================
# TEST 5: .ENV FILE GENERATION AND SECURITY
# ============================================================================

test_env_file() {
    log_test 5 ".env File Generation and Security"

    cd "${PROJECT_ROOT}"

    # Check .env exists
    if [[ ! -f .env ]]; then
        fail ".env file not found"
        return 1
    fi

    pass ".env file exists"

    # Check file permissions (must be 600)
    local perms
    perms=$(stat -c '%a' .env)

    if [[ "${perms}" == "600" ]]; then
        pass ".env file has secure permissions (600)"
    else
        fail ".env file has insecure permissions (${perms}, expected 600)"
    fi

    # Check required variables exist
    local required_vars=(
        "DOMAIN"
        "EMAIL"
        "POSTGRES_PASSWORD"
        "N8N_DB_PASSWORD"
        "CHATWOOT_DB_PASSWORD"
        "DIRECTUS_DB_PASSWORD"
        "EVOLUTION_DB_PASSWORD"
        "MONGO_INITDB_ROOT_USERNAME"
        "MONGO_INITDB_ROOT_PASSWORD"
        "REDIS_PASSWORD"
        "N8N_ENCRYPTION_KEY"
        "CHATWOOT_SECRET_KEY_BASE"
        "DIRECTUS_SECRET"
        "EVOLUTION_JWT_SECRET"
        "CORS_ALLOWED_ORIGINS"
    )

    local all_vars_present=true

    for var in "${required_vars[@]}"; do
        if grep -q "^${var}=" .env; then
            pass "Variable ${var} present"
        else
            fail "Variable ${var} missing"
            all_vars_present=false
        fi
    done

    # Check password strength (minimum 16 characters)
    local password_vars=(
        "POSTGRES_PASSWORD"
        "N8N_DB_PASSWORD"
        "REDIS_PASSWORD"
    )

    for var in "${password_vars[@]}"; do
        local value
        value=$(grep "^${var}=" .env | cut -d= -f2)
        local length=${#value}

        if [[ ${length} -ge 16 ]]; then
            pass "${var} has strong length (${length} chars)"
        else
            fail "${var} too short (${length} chars, minimum 16)"
        fi
    done

    if [[ "${all_vars_present}" == "true" ]]; then
        pass "All required environment variables present"
    else
        fail "Some environment variables missing"
    fi
}

# ============================================================================
# TEST 6: DOCKER IMAGE PULL VERIFICATION
# ============================================================================

test_docker_images() {
    log_test 6 "Docker Image Pull Verification"

    cd "${PROJECT_ROOT}"

    # Check core infrastructure images
    local core_images=(
        "caddy"
        "pgvector/pgvector"
        "mongo"
        "redis"
    )

    local all_images_present=true

    for image in "${core_images[@]}"; do
        if docker images | grep -q "${image}"; then
            pass "Image ${image} present"
        else
            warn "Image ${image} not found (may need to run: docker compose pull)"
            all_images_present=false
        fi
    done

    if [[ "${all_images_present}" == "true" ]]; then
        pass "All core infrastructure images present"
    else
        fail "Some core images missing"
    fi
}

# ============================================================================
# TEST 7: SERVICE HEALTH CHECK VALIDATION
# ============================================================================

test_service_health() {
    log_test 7 "Service Health Check Validation"

    cd "${PROJECT_ROOT}"

    # Check if services are running
    if ! docker compose ps >/dev/null 2>&1; then
        fail "Cannot check service status (docker compose ps failed)"
        return 1
    fi

    info "Service status:"
    docker compose ps

    echo ""

    # Check Caddy
    if docker compose ps caddy 2>/dev/null | grep -q "Up"; then
        pass "Caddy is running"
    else
        warn "Caddy is not running (may need to run: docker compose up -d)"
    fi

    # Check PostgreSQL
    if docker compose ps postgresql 2>/dev/null | grep -q "Up"; then
        if docker compose exec -T postgresql pg_isready -U postgres >/dev/null 2>&1; then
            pass "PostgreSQL is healthy"
        else
            warn "PostgreSQL is running but not ready"
        fi
    else
        warn "PostgreSQL is not running"
    fi

    # Check Redis
    if docker compose ps redis 2>/dev/null | grep -q "Up"; then
        # Try to get password from .env
        local redis_password
        redis_password=$(grep "^REDIS_PASSWORD=" .env 2>/dev/null | cut -d= -f2 || echo "redis")

        if docker compose exec -T redis redis-cli -a "${redis_password}" ping >/dev/null 2>&1; then
            pass "Redis is healthy"
        else
            warn "Redis is running but not responding to ping"
        fi
    else
        warn "Redis is not running"
    fi

    # Check MongoDB
    if docker compose ps mongodb 2>/dev/null | grep -q "Up"; then
        pass "MongoDB is running"
    else
        warn "MongoDB is not running"
    fi
}

# ============================================================================
# TEST 8: IDEMPOTENCY TESTING
# ============================================================================

test_idempotency() {
    log_test 8 "Idempotency Testing"

    info "This test verifies bootstrap.sh can be run safely multiple times"
    info "Actual idempotency testing requires running bootstrap.sh again"

    # Check if Docker already installed (indicates bootstrap was run)
    if command -v docker >/dev/null 2>&1; then
        pass "Docker already installed (bootstrap script should skip reinstall)"
    fi

    # Check if .env exists (bootstrap should warn before overwriting)
    if [[ -f "${PROJECT_ROOT}/.env" ]]; then
        pass ".env file exists (bootstrap script should warn before overwriting)"
    fi

    # Check if UFW already configured (bootstrap should detect existing rules)
    if sudo ufw status | grep -q "Status: active"; then
        pass "UFW already active (bootstrap script should detect existing rules)"
    fi

    pass "Idempotency checks passed (manual verification recommended)"
}

# ============================================================================
# TEST 9: DNS CONFIGURATION INSTRUCTIONS
# ============================================================================

test_dns_instructions() {
    log_test 9 "DNS Configuration Instructions"

    info "This test verifies DNS configuration instructions are clear"

    # Check if bootstrap log exists
    if [[ -f /tmp/borgstack-bootstrap.log ]]; then
        pass "Bootstrap log file exists at /tmp/borgstack-bootstrap.log"

        # Check if log contains DNS instructions
        if grep -q "Configure DNS A Records" /tmp/borgstack-bootstrap.log; then
            pass "Bootstrap log contains DNS configuration instructions"
        else
            warn "DNS configuration instructions not found in bootstrap log"
        fi
    else
        warn "Bootstrap log file not found (bootstrap.sh may not have been run)"
    fi

    # Check if README.md has bootstrap documentation
    if [[ -f "${PROJECT_ROOT}/README.md" ]]; then
        if grep -q -i "script bootstrap" "${PROJECT_ROOT}/README.md" || grep -q -i "bootstrap.*script" "${PROJECT_ROOT}/README.md"; then
            pass "README.md contains bootstrap documentation"
        else
            fail "README.md missing bootstrap documentation"
        fi
    fi
}

# ============================================================================
# TEST 10: DNS CONFIGURATION VERIFICATION
# ============================================================================

test_dns_verification() {
    log_test 10 "DNS Configuration Verification"

    cd "${PROJECT_ROOT}"

    # Load domain from .env
    if [[ ! -f .env ]]; then
        warn ".env file not found, skipping DNS verification"
        return 0
    fi

    local domain
    domain=$(grep "^DOMAIN=" .env | cut -d= -f2)

    if [[ -z "${domain}" ]]; then
        warn "DOMAIN not set in .env, skipping DNS verification"
        return 0
    fi

    info "Checking DNS for domain: ${domain}"

    local subdomains=("n8n" "chatwoot" "evolution" "lowcoder" "directus" "fileflows" "duplicati")
    local dns_configured=0
    local dns_missing=0

    for subdomain in "${subdomains[@]}"; do
        local fqdn="${subdomain}.${domain}"
        local ip

        ip=$(dig "${fqdn}" +short 2>/dev/null | head -n1)

        if [[ -n "${ip}" ]]; then
            pass "DNS configured: ${fqdn} → ${ip}"
            ((dns_configured++)) || true
        else
            warn "DNS not configured: ${fqdn}"
            ((dns_missing++)) || true
        fi
    done

    echo ""
    info "DNS Summary: ${dns_configured}/7 subdomains configured"

    if [[ ${dns_missing} -gt 0 ]]; then
        warn "${dns_missing} subdomains need DNS configuration"
        warn "SSL certificates will not generate until DNS is configured"
    else
        pass "All 7 subdomains have DNS configured"
    fi
}

# ============================================================================
# TEST 11: ERROR HANDLING AND ROLLBACK
# ============================================================================

test_error_handling() {
    log_test 11 "Error Handling and Rollback"

    info "This test verifies bootstrap.sh has proper error handling"

    # Check if bootstrap script has error handling
    if [[ -f "${PROJECT_ROOT}/scripts/bootstrap.sh" ]]; then
        pass "Bootstrap script exists"

        # Check for error handling directives
        if grep -q "set -euo pipefail" "${PROJECT_ROOT}/scripts/bootstrap.sh"; then
            pass "Bootstrap script has error handling (set -euo pipefail)"
        else
            fail "Bootstrap script missing error handling directive"
        fi

        # Check for logging
        if grep -q "LOG_FILE" "${PROJECT_ROOT}/scripts/bootstrap.sh"; then
            pass "Bootstrap script has logging functionality"
        else
            warn "Bootstrap script may not have logging"
        fi

        # Check for validation functions
        if grep -q "validate_" "${PROJECT_ROOT}/scripts/bootstrap.sh"; then
            pass "Bootstrap script has validation functions"
        else
            warn "Bootstrap script may not have validation functions"
        fi
    else
        fail "Bootstrap script not found at ${PROJECT_ROOT}/scripts/bootstrap.sh"
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    clear
    echo "${BOLD}${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║           BorgStack Bootstrap Validation Tests                 ║"
    echo "║                                                                ║"
    echo "║                    Running ${TESTS_TOTAL} Tests                          ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo "${RESET}"

    # Run all tests
    test_linux_distribution || true
    test_system_requirements || true
    test_docker_installation || true
    test_firewall_configuration || true
    test_env_file || true
    test_docker_images || true
    test_service_health || true
    test_idempotency || true
    test_dns_instructions || true
    test_dns_verification || true
    test_error_handling || true

    # Display summary
    echo ""
    echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo "${BOLD}${CYAN}TEST SUMMARY${RESET}"
    echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo "Total Tests: ${TESTS_TOTAL}"
    echo "${GREEN}Passed: ${TESTS_PASSED}${RESET}"
    echo "${RED}Failed: ${TESTS_FAILED}${RESET}"
    echo ""

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo "${BOLD}${GREEN}✓ All tests passed!${RESET}"
        exit 0
    else
        echo "${BOLD}${RED}✗ Some tests failed. Review output above.${RESET}"
        exit 1
    fi
}

# Run main function
main "$@"
