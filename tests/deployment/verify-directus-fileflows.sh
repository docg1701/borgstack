#!/usr/bin/env bash
#
# Directus-FileFlows Integration Deployment Verification Test
# Story 4.3: Directus-FileFlows Integration
#
# This script validates the Directus-FileFlows integration configuration,
# n8n workflow setup, and deployment readiness.
#
# Usage:
#   ./tests/deployment/verify-directus-fileflows.sh
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed
#

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=10

# Navigate to project root
cd "$(dirname "$0")/../.."

echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo "Directus-FileFlows Integration - Deployment Validation Tests"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# Test 1: n8n workflow files exist
echo "Test 1: Verifying n8n workflow files..."
WORKFLOW_FILES=(
  "config/n8n/workflows/directus-fileflows-upload.json"
  "config/n8n/workflows/directus-fileflows-complete.json"
  "config/n8n/workflows/directus-fileflows-error.json"
  "config/n8n/workflows/media-processing-stats.json"
  "config/n8n/workflows/missed-files-detector.json"
)

ALL_FOUND=true
for workflow in "${WORKFLOW_FILES[@]}"; do
  if [ -f "$workflow" ]; then
    echo -e "${GREEN}✓${NC} $workflow exists"
  else
    echo -e "${RED}✗${NC} $workflow not found"
    ALL_FOUND=false
  fi
done

if [ "$ALL_FOUND" = true ]; then
  echo -e "${GREEN}✓${NC} All 5 workflow files exist"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} Missing workflow files"
  ((TESTS_FAILED++))
fi
echo ""

# Test 2: Integration documentation exists
echo "Test 2: Verifying integration documentation..."
if [ -f "docs/04-integrations/directus-fileflows.md" ] && [ -f "docs/MANUAL_TASKS_4.3.md" ]; then
  echo -e "${GREEN}✓${NC} Integration documentation exists"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} Documentation missing"
  ((TESTS_FAILED++))
fi
echo ""

# Test 3: Environment variables in .env.example
echo "Test 3: Verifying environment variables in .env.example..."
VARS_OK=true
if ! grep -q "DIRECTUS_API_TOKEN=" .env.example; then
  echo -e "${RED}✗${NC} DIRECTUS_API_TOKEN missing"
  VARS_OK=false
fi
if ! grep -q "DIRECTUS_WEBHOOK_SECRET=" .env.example; then
  echo -e "${RED}✗${NC} DIRECTUS_WEBHOOK_SECRET missing"
  VARS_OK=false
fi
if ! grep -q "FILEFLOWS_DELETE_ORIGINALS=" .env.example; then
  echo -e "${RED}✗${NC} FILEFLOWS_DELETE_ORIGINALS missing"
  VARS_OK=false
fi

if [ "$VARS_OK" = true ]; then
  echo -e "${GREEN}✓${NC} All required environment variables in .env.example"
  ((TESTS_PASSED++))
else
  ((TESTS_FAILED++))
fi
echo ""

# Test 4: n8n volume mounts
echo "Test 4: Verifying n8n volume mounts in docker-compose.yml..."
MOUNTS_OK=true

# Check directly in docker-compose.yml for volume mounts (n8n service is ~50 lines long)
if ! grep -A 50 "^  n8n:" docker-compose.yml | grep -q "borgstack_directus_uploads:/directus/uploads:ro"; then
  echo -e "${RED}✗${NC} n8n missing borgstack_directus_uploads mount"
  MOUNTS_OK=false
fi
if ! grep -A 50 "^  n8n:" docker-compose.yml | grep -q "borgstack_fileflows_input:/fileflows/input:rw"; then
  echo -e "${RED}✗${NC} n8n missing borgstack_fileflows_input mount"
  MOUNTS_OK=false
fi

if [ "$MOUNTS_OK" = true ]; then
  echo -e "${GREEN}✓${NC} n8n has correct volume mounts"
  ((TESTS_PASSED++))
else
  ((TESTS_FAILED++))
fi
echo ""

# Test 5: Workflow README documentation
echo "Test 5: Verifying workflow documentation..."
if [ -f "config/n8n/workflows/README.md" ] && \
   grep -q "directus-fileflows-upload" config/n8n/workflows/README.md && \
   grep -q "missed-files-detector" config/n8n/workflows/README.md; then
  echo -e "${GREEN}✓${NC} Workflow documentation complete"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} Workflow documentation incomplete"
  ((TESTS_FAILED++))
fi
echo ""

# Test 6: Directus configuration guide
echo "Test 6: Verifying Directus configuration guide..."
if [ -f "config/directus/README.md" ]; then
  echo -e "${GREEN}✓${NC} Directus configuration guide exists"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} Directus configuration guide missing"
  ((TESTS_FAILED++))
fi
echo ""

# Test 7: FileFlows configuration guide
echo "Test 7: Verifying FileFlows configuration guide..."
if [ -f "config/fileflows/README.md" ]; then
  echo -e "${GREEN}✓${NC} FileFlows configuration guide exists"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} FileFlows configuration guide missing"
  ((TESTS_FAILED++))
fi
echo ""

# Test 8: Manual tasks documentation
echo "Test 8: Verifying manual tasks documentation..."
if [ -f "docs/MANUAL_TASKS_4.3.md" ] && grep -q "Task 9" docs/MANUAL_TASKS_4.3.md; then
  echo -e "${GREEN}✓${NC} Manual tasks documentation complete (9 tasks)"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} Manual tasks documentation incomplete"
  ((TESTS_FAILED++))
fi
echo ""

# Test 9: CI workflow integration
echo "Test 9: Verifying CI workflow integration..."
if grep -q "validate-directus-fileflows:" .github/workflows/ci.yml; then
  echo -e "${GREEN}✓${NC} CI workflow job exists"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} CI workflow job missing"
  ((TESTS_FAILED++))
fi
echo ""

# Test 10: Workflow HMAC validation
echo "Test 10: Verifying HMAC signature validation in upload workflow..."
if grep -q "Validate HMAC Signature" config/n8n/workflows/directus-fileflows-upload.json; then
  echo -e "${GREEN}✓${NC} HMAC validation implemented"
  ((TESTS_PASSED++))
else
  echo -e "${RED}✗${NC} HMAC validation not found"
  ((TESTS_FAILED++))
fi
echo ""

# Summary
echo "═══════════════════════════════════════════════════════════════════════════"
echo "Test Results Summary"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed!${NC}"
  echo ""
  echo "Directus-FileFlows integration is ready for deployment."
  echo ""
  echo "Next steps:"
  echo "  1. Execute manual tasks: docs/MANUAL_TASKS_4.3.md (~100 min)"
  echo "  2. Import n8n workflows (5 files)"
  echo "  3. Configure Directus Flow + webhook security"
  echo "  4. Configure FileFlows webhooks and flows"
  echo "  5. Test end-to-end: Upload → Process → Verify"
  exit 0
else
  echo -e "${RED}✗ Some tests failed. Review output above.${NC}"
  exit 1
fi
