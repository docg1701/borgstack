# BorgStack Test Suite

Comprehensive integration testing suite for BorgStack infrastructure deployment validation.

## Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Test Reports](#test-reports)
- [Test Categories](#test-categories)
- [CI/CD Integration](#cicd-integration)

## Overview

The BorgStack test suite validates:
- **Deployment verification** (15 scripts): All services configured and healthy
- **Storage integration** (12 tests): SeaweedFS Filer API operations
- **End-to-end workflows** (23 tests): Complete user journeys across services
- **Component integration** (29 tests): Service-to-service communication
- **Failure scenarios** (14 tests): Resilience and recovery mechanisms

**Total:** 93+ automated tests

## Test Structure

```
tests/
├── deployment/              # Deployment verification scripts (15)
│   ├── verify-bootstrap.sh
│   ├── verify-caddy.sh
│   ├── verify-chatwoot.sh
│   ├── verify-directus.sh
│   ├── verify-duplicati.sh
│   ├── verify-evolution.sh
│   ├── verify-fileflows.sh
│   ├── verify-lowcoder.sh
│   ├── verify-mongodb.sh
│   ├── verify-n8n.sh
│   ├── verify-network-isolation.sh
│   ├── verify-postgresql.sh
│   ├── verify-redis.sh
│   ├── verify-seaweedfs.sh
│   └── verify-directus-fileflows.sh
│
├── integration/             # Integration test suites
│   ├── test-storage-integration.sh      # SeaweedFS tests (12)
│   ├── test-e2e-workflows.sh            # E2E workflows (23)
│   ├── test-component-integration.sh    # Component integration (29)
│   └── test-failure-scenarios.sh        # Failure scenarios (14)
│
├── run-all-tests.sh         # Master test runner
└── README.md                # This file
```

## Running Tests

### Run All Tests

```bash
# Run complete test suite (includes failure scenarios)
./tests/run-all-tests.sh

# Skip destructive failure scenario tests
./tests/run-all-tests.sh --skip-failure-scenarios
```

**Estimated Time:**
- With failure scenarios: 15-20 minutes
- Without failure scenarios: 10-15 minutes

### Run Individual Test Suites

```bash
# Deployment verification
./tests/deployment/verify-postgresql.sh
./tests/deployment/verify-n8n.sh
# ... (any verify-*.sh script)

# Integration tests
./tests/integration/test-storage-integration.sh
./tests/integration/test-e2e-workflows.sh
./tests/integration/test-component-integration.sh

# Failure scenarios (⚠️ DESTRUCTIVE - temporarily disrupts services)
./tests/integration/test-failure-scenarios.sh
```

### Run With Verbose Output

```bash
# Enable bash debug mode
bash -x ./tests/integration/test-e2e-workflows.sh
```

## Test Reports

The master test runner generates two report formats:

### JSON Report
```bash
docs/qa/test-results-YYYYMMDD-HHMMSS.json
```

Contains:
- Execution timestamp
- System metrics (CPU, memory, disk)
- Test summary (total, passed, failed, skipped)
- Per-suite breakdown with duration
- Pass rate percentage

### Markdown Report
```bash
docs/qa/test-results-YYYYMMDD-HHMMSS.md
```

Human-readable report with:
- Executive summary
- System metrics table
- Test suite breakdown table
- Test coverage matrix
- Recommendations and next steps

## Test Categories

### 1. Deployment Verification Tests

**Purpose:** Validate that all services are correctly deployed and configured

**Coverage:**
- Container health checks
- Volume and network configuration
- Service-specific configuration validation
- Database schema initialization
- SSL certificate validation

**Example:**
```bash
./tests/deployment/verify-postgresql.sh
```

**Tests (per service):**
- Docker Compose syntax validation
- Image version verification
- Network isolation configuration
- Health check validation
- Database/service-specific checks

### 2. Storage Integration Tests

**Purpose:** Validate SeaweedFS Filer API integration

**Coverage:**
- CRUD operations (create, read, update, delete)
- Directory operations
- Concurrent write operations
- Data integrity verification
- Service storage configuration

**Example:**
```bash
./tests/integration/test-storage-integration.sh
```

**Tests:**
- SeaweedFS health and API accessibility
- Bucket/directory creation
- File upload/download
- Data integrity (checksums)
- Concurrent operations (5 parallel uploads)

### 3. End-to-End Workflow Tests

**Purpose:** Validate complete user workflows across services

**Coverage:**
- WhatsApp → Chatwoot customer service workflow
- Bootstrap and deployment workflow
- Automated backup process workflow
- Media file processing pipeline workflow

**Example:**
```bash
./tests/integration/test-e2e-workflows.sh
```

**Tests (23 automated + 10 manual-config):**
- Service health and accessibility
- Database connectivity
- Volume and network existence
- Infrastructure readiness
- Note: Full workflows require manual service configuration

### 4. Component Integration Tests

**Purpose:** Validate service-to-service communication

**Coverage:**
- Database connections (PostgreSQL, MongoDB, Redis)
- Storage integration (SeaweedFS Filer API)
- API connectivity (n8n, Chatwoot, Evolution, Directus, FileFlows)
- Reverse proxy routing (Caddy → all services)
- Security (authentication, CORS)

**Example:**
```bash
./tests/integration/test-component-integration.sh
```

**Tests (29 automated + 7 manual-verify):**
- 8 database integration tests
- 3 storage integration tests
- 8 API integration tests
- 8 reverse proxy tests
- 5 security tests
- 4 additional integration tests

### 5. Failure Scenario Tests

**Purpose:** Validate system resilience and recovery

⚠️ **WARNING:** These tests are **DESTRUCTIVE** and will temporarily disrupt services

**Coverage:**
- Database connection loss and recovery
- Redis connection loss and recovery
- Network partition scenarios
- Service restart under load
- Invalid configuration handling

**Example:**
```bash
./tests/integration/test-failure-scenarios.sh
```

**Tests (14 executed + 2 skipped):**
- PostgreSQL stop/restart + service recovery
- Redis stop/restart + service recovery
- Network isolation + reconnection
- Service restart validation
- Note: Disk exhaustion skipped (too destructive)

## CI/CD Integration

### GitHub Actions Workflow

The test suite integrates with GitHub Actions CI/CD pipeline:

```yaml
# .github/workflows/ci.yml
jobs:
  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - name: Run deployment verification
        run: ./tests/run-all-tests.sh --skip-failure-scenarios

      - name: Upload test results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: docs/qa/test-results-*.{json,md}
```

**CI Configuration:**
- Runs on: Push to `main`, pull request, manual dispatch
- Timeout: 30 minutes
- Artifacts: JSON and Markdown test reports
- Failure scenarios: **Skipped in CI** (too destructive)

### Local Development

Before committing:

```bash
# Quick validation (deployment + integration)
./tests/run-all-tests.sh --skip-failure-scenarios

# Full validation (includes failure scenarios)
./tests/run-all-tests.sh
```

## Test Standards

### Test Script Guidelines

1. **Exit Codes:**
   - `0` = All tests passed
   - `1` = One or more tests failed

2. **Output Format:**
   ```bash
   ✅ Test X/Y: Description... PASS
   ❌ Test X/Y: Description... FAIL
   ⏭️  Test X/Y: Description... SKIP
   ```

3. **Error Handling:**
   - Use `set +e` for integration tests (run all tests even if one fails)
   - Use `set -e` for deployment tests (fail fast on critical issues)

4. **Cleanup:**
   - Always clean up test data (files, database records)
   - Restore services to original state after failure tests

5. **Independence:**
   - Each test should run standalone
   - No dependencies between test scripts
   - Idempotent execution (can run multiple times)

### Test Data Management

- Use predictable test identifiers (e.g., `test-contact-12345`)
- Store test files in `/tmp` or designated test volumes
- Clean up after test execution
- Never use production data

## Troubleshooting

### Tests Failing

1. **Check service health:**
   ```bash
   docker compose ps
   ```

2. **View service logs:**
   ```bash
   docker compose logs <service-name>
   ```

3. **Restart all services:**
   ```bash
   docker compose restart
   ```

4. **Clean restart:**
   ```bash
   docker compose down
   docker compose up -d
   ```

### Common Issues

**Issue:** Tests fail with "connection refused"
- **Cause:** Service not fully started
- **Fix:** Wait for all services healthy: `docker compose ps`

**Issue:** Tests fail with "command not found"
- **Cause:** Script not executable
- **Fix:** `chmod +x tests/**/*.sh`

**Issue:** Failure scenario tests leave services degraded
- **Cause:** Test interrupted before cleanup
- **Fix:** Run `docker compose restart` to restore all services

## Performance Baselines

Typical test execution times (on 36GB RAM, 8 vCPU server):

| Test Suite | Tests | Duration |
|------------|-------|----------|
| Deployment Verification | 15 scripts | ~5-8 min |
| Storage Integration | 12 tests | ~30-60s |
| E2E Workflows | 23 tests | ~1-2 min |
| Component Integration | 29 tests | ~1-2 min |
| Failure Scenarios | 14 tests | ~3-5 min |
| **Total** | **93+ tests** | **10-20 min** |

## Contributing

When adding new tests:

1. Follow existing test script structure
2. Add clear test descriptions
3. Include proper error handling
4. Document in this README
5. Update test coverage matrix

## Support

For issues or questions:
- Review test output and logs
- Check [docs/05-troubleshooting.md](../05-troubleshooting.md)
- Report issues: https://github.com/yourusername/borgstack/issues

---

*Test suite developed as part of Story 6.1: Integration Testing Suite*
