#!/bin/bash
# ============================================================================
# BorgStack - MongoDB Deployment Validation Tests
# ============================================================================
#
# Purpose: Validate MongoDB configuration and deployment
# Tests all Acceptance Criteria from Story 1.7
#
# Usage: ./tests/deployment/verify-mongodb.sh
#
# Exit Codes:
#   0 = All tests passed
#   1 = One or more tests failed
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Helper Functions
# ============================================================================

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# ============================================================================
# Test 1: Docker Compose Configuration Validation (AC: All)
# ============================================================================
log_test "Test 1: Validating docker-compose.yml syntax"

if docker compose config --quiet; then
    log_success "docker-compose.yml syntax is valid"
else
    log_error "docker-compose.yml validation failed"
fi

# ============================================================================
# Test 2: MongoDB Image Verification (AC: 1)
# ============================================================================
log_test "Test 2: Verifying MongoDB image version"

if docker compose config | grep -q "image: mongo:7.0"; then
    log_success "MongoDB 7.0 image configured correctly"
else
    log_error "MongoDB image not configured with mongo:7.0"
fi

# ============================================================================
# Test 3: Network Configuration Verification (AC: 1)
# ============================================================================
log_test "Test 3: Verifying network isolation configuration"

# Check MongoDB is on internal network (which creates borgstack_internal)
if docker compose config | grep -A 30 "mongodb:" | grep -q "internal"; then
    log_success "MongoDB connected to internal network"
else
    log_error "MongoDB not connected to internal network"
fi

# Verify NO port exposure to host (security requirement from Story 1.2)
if docker compose config | grep -A 30 "mongodb:" | grep -E "^\s+ports:" > /dev/null 2>&1; then
    log_error "MongoDB has ports exposed to host (security violation)"
else
    log_success "MongoDB has no port exposure to host (secure configuration)"
fi

# ============================================================================
# Test 4: Volume Configuration Verification (AC: 4)
# ============================================================================
log_test "Test 4: Verifying volume configuration"

# Check mongodb_data volume exists in config (Docker Compose naming convention)
if docker compose config | grep -q "mongodb_data"; then
    log_success "mongodb_data volume configured correctly"
else
    log_error "mongodb_data volume not found in configuration"
fi

# Verify volume mount point (Docker Compose uses short names in service config)
if docker compose config | grep -A 50 "mongodb:" | grep -q "/data/db"; then
    log_success "MongoDB data volume mounted at /data/db correctly"
else
    log_error "MongoDB data volume mount not configured correctly"
fi

# ============================================================================
# Test 5: Environment Variables Configuration (AC: 2, 3)
# ============================================================================
log_test "Test 5: Verifying environment variables configuration"

# Check MONGO_INITDB_ROOT_USERNAME is set to admin
if docker compose config | grep -A 30 "mongodb:" | grep -q "MONGO_INITDB_ROOT_USERNAME: admin"; then
    log_success "MONGO_INITDB_ROOT_USERNAME set to 'admin'"
else
    log_error "MONGO_INITDB_ROOT_USERNAME not set to 'admin'"
fi

# Check MONGO_INITDB_ROOT_PASSWORD is configured (from env var)
if docker compose config | grep -A 30 "mongodb:" | grep -q "MONGO_INITDB_ROOT_PASSWORD:"; then
    log_success "MONGO_INITDB_ROOT_PASSWORD configured from environment"
else
    log_error "MONGO_INITDB_ROOT_PASSWORD not configured"
fi

# Check LOWCODER_DB_PASSWORD is configured (for init script)
if docker compose config | grep -A 30 "mongodb:" | grep -q "LOWCODER_DB_PASSWORD:"; then
    log_success "LOWCODER_DB_PASSWORD configured from environment"
else
    log_error "LOWCODER_DB_PASSWORD not configured"
fi

# ============================================================================
# Test 6: Initialization Script Verification (AC: 2, 3)
# ============================================================================
log_test "Test 6: Verifying initialization script configuration"

# Check init-mongo.js is mounted in docker-compose.yml
if docker compose config | grep -A 30 "mongodb:" | grep -q "init-mongo.js"; then
    log_success "init-mongo.js initialization script mounted"
else
    log_error "init-mongo.js initialization script not mounted"
fi

# Verify init-mongo.js file exists
if [ -f "config/mongodb/init-mongo.js" ]; then
    log_success "config/mongodb/init-mongo.js file exists"
else
    log_error "config/mongodb/init-mongo.js file not found"
fi

# ============================================================================
# Test 7: Health Check Configuration (AC: 6)
# ============================================================================
log_test "Test 7: Verifying health check configuration"

# Check health check is configured with mongosh
if docker compose config | grep -A 35 "mongodb:" | grep -q "mongosh"; then
    log_success "MongoDB health check configured with mongosh"
else
    log_error "MongoDB health check not configured correctly"
fi

# Verify health check parameters
if docker compose config | grep -A 40 "mongodb:" | grep -q "interval: 10s" && \
   docker compose config | grep -A 40 "mongodb:" | grep -q "timeout: 5s" && \
   docker compose config | grep -A 40 "mongodb:" | grep -q "retries: 5"; then
    log_success "Health check parameters configured correctly (interval: 10s, timeout: 5s, retries: 5)"
else
    log_error "Health check parameters not configured correctly"
fi

# ============================================================================
# Test 8: MongoDB Container Running (AC: 1)
# ============================================================================
log_test "Test 8: Starting MongoDB container and verifying it's running"

# Clean up any existing MongoDB container and volume to ensure init script runs
# MongoDB init scripts only run on first startup (when /data/db is empty)
log_info "Cleaning up any existing MongoDB container and volume..."
docker compose rm -sf mongodb 2>/dev/null || true
# Volume cleanup not needed - docker compose down -v handles it
docker volume rm borgstack_mongodb_data 2>/dev/null || true

log_info "Starting MongoDB container with fresh volume..."
docker compose up -d mongodb

# Wait for container to start
log_info "Waiting for MongoDB container to initialize (30 seconds)..."
sleep 30

# Verify container is running
if docker compose ps mongodb | grep -q "Up"; then
    log_success "MongoDB container is running"
else
    log_error "MongoDB container is not running"
    docker compose logs mongodb
fi

# ============================================================================
# Test 9: MongoDB Health Check Passing (AC: 6)
# ============================================================================
log_test "Test 9: Verifying MongoDB health check passes"

# Wait for health check to pass (up to 60 seconds)
log_info "Waiting for MongoDB health check to pass..."
for i in {1..12}; do
    if docker compose ps mongodb | grep -q "healthy"; then
        log_success "MongoDB container health check is passing"
        break
    fi
    if [ $i -eq 12 ]; then
        log_error "MongoDB health check did not pass within 60 seconds"
        docker compose logs mongodb | tail -20
    else
        sleep 5
    fi
done

# ============================================================================
# Test 10: Root User Authentication (AC: 2)
# ============================================================================
log_test "Test 10: Verifying MongoDB root user authentication"

# Load .env file to get passwords
if [ -f ".env" ]; then
    source .env
else
    log_error ".env file not found - cannot test authentication"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test root admin authentication
if [ -n "${MONGODB_ROOT_PASSWORD:-}" ]; then
    if docker compose exec -T mongodb mongosh --username admin --password "${MONGODB_ROOT_PASSWORD}" --authenticationDatabase admin --eval "db.adminCommand('ping')" | grep -q "ok: 1"; then
        log_success "MongoDB root user (admin) authentication successful"
    else
        log_error "MongoDB root user (admin) authentication failed"
        docker compose logs mongodb | tail -10
    fi
else
    log_error "MONGODB_ROOT_PASSWORD not set in .env file"
fi

# ============================================================================
# Test 11: Lowcoder Database Creation (AC: 3)
# ============================================================================
log_test "Test 11: Verifying 'lowcoder' database can be created/accessed"

if [ -n "${MONGODB_ROOT_PASSWORD:-}" ] && [ -n "${LOWCODER_DB_PASSWORD:-}" ]; then
    # Create the lowcoder database by inserting a document as lowcoder_user
    # This mimics what happens when Lowcoder first connects
    if docker compose exec -T mongodb mongosh --username lowcoder_user --password "${LOWCODER_DB_PASSWORD}" --authenticationDatabase lowcoder lowcoder --eval "db.init.insertOne({ initialized: true, timestamp: new Date() })" | grep -q "acknowledged: true"; then
        log_success "'lowcoder' database created and accessible"
    else
        log_error "'lowcoder' database creation failed"
        log_info "Available databases:"
        docker compose exec -T mongodb mongosh --username admin --password "${MONGODB_ROOT_PASSWORD}" --authenticationDatabase admin --eval "db.adminCommand('listDatabases')"
    fi
else
    log_error "Cannot verify database without MONGODB_ROOT_PASSWORD and LOWCODER_DB_PASSWORD"
fi

# ============================================================================
# Test 12: Lowcoder User Authentication (AC: 3)
# ============================================================================
log_test "Test 12: Verifying lowcoder_user can authenticate and access lowcoder database"

if [ -n "${LOWCODER_DB_PASSWORD:-}" ]; then
    if docker compose exec -T mongodb mongosh --username lowcoder_user --password "${LOWCODER_DB_PASSWORD}" --authenticationDatabase lowcoder lowcoder --eval "db.runCommand({ ping: 1 })" | grep -q "ok: 1"; then
        log_success "lowcoder_user authentication successful"
    else
        log_error "lowcoder_user authentication failed"
        docker compose logs mongodb | tail -10
    fi
else
    log_error "LOWCODER_DB_PASSWORD not set in .env file"
fi

# ============================================================================
# Test 13: Lowcoder User Write Permission (AC: 3)
# ============================================================================
log_test "Test 13: Verifying lowcoder_user has write permissions to lowcoder database"

if [ -n "${LOWCODER_DB_PASSWORD:-}" ]; then
    # Try to insert a test document
    if docker compose exec -T mongodb mongosh --username lowcoder_user --password "${LOWCODER_DB_PASSWORD}" --authenticationDatabase lowcoder lowcoder --eval "db.test_collection.insertOne({ test: 'BorgStack MongoDB Test', timestamp: new Date() })" | grep -q "acknowledged: true"; then
        log_success "lowcoder_user has write permissions to lowcoder database"

        # Clean up test document
        docker compose exec -T mongodb mongosh --username lowcoder_user --password "${LOWCODER_DB_PASSWORD}" --authenticationDatabase lowcoder lowcoder --eval "db.test_collection.deleteOne({ test: 'BorgStack MongoDB Test' })" > /dev/null 2>&1
    else
        log_error "lowcoder_user does not have write permissions"
    fi
else
    log_error "Cannot verify write permissions without LOWCODER_DB_PASSWORD"
fi

# ============================================================================
# Test 14: Persistent Volume Mounted (AC: 4)
# ============================================================================
log_test "Test 14: Verifying persistent volume is mounted"

# Check if volume exists in Docker
if docker volume ls | grep -q "borgstack_mongodb_data"; then
    log_success "borgstack_mongodb_data volume exists in Docker"
else
    log_error "borgstack_mongodb_data volume not found in Docker"
fi

# Verify volume is mounted in container
if docker compose exec -T mongodb ls /data/db | grep -q "mongod.lock"; then
    log_success "MongoDB data directory (/data/db) is mounted and contains MongoDB files"
else
    log_error "MongoDB data directory not properly mounted"
fi

# ============================================================================
# Test 15: Security - No Port Exposure (AC: Network Isolation)
# ============================================================================
log_test "Test 15: Verifying MongoDB does not expose ports to host (security check)"

# Check that MongoDB container has no published ports using docker inspect
CONTAINER_ID=$(docker compose ps -q mongodb)
if [ -n "$CONTAINER_ID" ]; then
    PORT_BINDINGS=$(docker inspect "$CONTAINER_ID" --format='{{json .NetworkSettings.Ports}}')
    if echo "$PORT_BINDINGS" | grep -q "HostPort"; then
        log_error "MongoDB is exposing port 27017 to host (security violation)"
    else
        log_success "MongoDB is not exposing ports to host (secure configuration)"
    fi
else
    log_error "MongoDB container not found"
fi

# ============================================================================
# Test Summary
# ============================================================================
echo ""
echo "============================================================================"
echo -e "${BLUE}MongoDB Validation Test Summary${NC}"
echo "============================================================================"
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo "============================================================================"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All MongoDB validation tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some MongoDB validation tests failed${NC}"
    echo -e "${YELLOW}Review the output above for details${NC}"
    exit 1
fi
