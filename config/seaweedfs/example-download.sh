#!/usr/bin/env bash
#
# SeaweedFS S3 Download Examples
#
# This script demonstrates various file download scenarios using AWS CLI with SeaweedFS.
# Before running, ensure AWS CLI is configured and test files uploaded (run aws-cli-config.sh and example-upload.sh).
#
# Prerequisites:
#   1. AWS CLI installed and configured (./config/seaweedfs/aws-cli-config.sh)
#   2. SeaweedFS running and healthy (docker compose ps seaweedfs)
#   3. Test files uploaded (./config/seaweedfs/example-upload.sh)
#
# Usage:
#   ./config/seaweedfs/example-download.sh
#
# Examples:
#   - Download single file
#   - Download multiple files
#   - Download entire directory
#   - Download with sync (incremental)
#   - Generate presigned URLs
#   - Download specific file versions
#

set -euo pipefail

# SeaweedFS S3 endpoint
S3_ENDPOINT="http://localhost:8333"

# Main bucket
BUCKET="borgstack"

# Download destination
DOWNLOAD_DIR="/tmp/seaweedfs-downloads"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "SeaweedFS S3 Download Examples"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
    echo ""
}

# Cleanup and create download directory
setup_download_dir() {
    print_section "Setting up download directory"

    rm -rf "$DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR"

    echo -e "${GREEN}✓${NC} Download directory created: $DOWNLOAD_DIR"
}

# Example 1: Download a single file
example_single_file() {
    print_section "Example 1: Download Single File"

    local dest="$DOWNLOAD_DIR/single-file"
    mkdir -p "$dest"

    echo "Downloading s3://$BUCKET/test/seaweedfs-test.txt..."
    aws --endpoint-url "$S3_ENDPOINT" s3 cp "s3://$BUCKET/test/seaweedfs-test.txt" "$dest/"

    echo -e "${GREEN}✓${NC} File downloaded successfully"
    echo ""
    echo "Downloaded file content:"
    cat "$dest/seaweedfs-test.txt"
}

# Example 2: Download multiple files
example_multiple_files() {
    print_section "Example 2: Download Multiple Files"

    local dest="$DOWNLOAD_DIR/multiple-files"
    mkdir -p "$dest"

    echo "Downloading all files from s3://$BUCKET/test/multiple/..."
    aws --endpoint-url "$S3_ENDPOINT" s3 sync "s3://$BUCKET/test/multiple/" "$dest/"

    echo -e "${GREEN}✓${NC} Files downloaded successfully"
    echo ""
    echo "Downloaded files:"
    ls -lh "$dest/"
}

# Example 3: Download entire directory structure
example_directory() {
    print_section "Example 3: Download Directory Structure"

    local dest="$DOWNLOAD_DIR/directory"
    mkdir -p "$dest"

    echo "Downloading directory structure from s3://$BUCKET/test/directory/..."
    aws --endpoint-url "$S3_ENDPOINT" s3 sync "s3://$BUCKET/test/directory/" "$dest/"

    echo -e "${GREEN}✓${NC} Directory downloaded successfully"
    echo ""
    echo "Directory structure:"
    tree "$dest/" 2>/dev/null || find "$dest/" -type f
}

# Example 4: Incremental download with sync
example_sync_download() {
    print_section "Example 4: Incremental Download (Sync)"

    local dest="$DOWNLOAD_DIR/sync-test"
    mkdir -p "$dest"

    echo "First sync (downloads all files):"
    aws --endpoint-url "$S3_ENDPOINT" s3 sync "s3://$BUCKET/test/multiple/" "$dest/"

    echo ""
    echo "Second sync (skips unchanged files):"
    aws --endpoint-url "$S3_ENDPOINT" s3 sync "s3://$BUCKET/test/multiple/" "$dest/"

    echo -e "${GREEN}✓${NC} Sync completed - only new/changed files downloaded"
}

# Example 5: Download with filtering
example_filtered_download() {
    print_section "Example 5: Download Filtered Files"

    local dest="$DOWNLOAD_DIR/filtered"
    mkdir -p "$dest"

    echo "Downloading only .txt files..."
    aws --endpoint-url "$S3_ENDPOINT" s3 sync "s3://$BUCKET/test/content-types/" "$dest/" \
        --exclude "*" --include "*.txt"

    echo -e "${GREEN}✓${NC} Filtered download completed"
    echo ""
    echo "Downloaded .txt files:"
    ls -lh "$dest/"
}

# Example 6: Download from specific service prefixes
example_service_prefixes() {
    print_section "Example 6: Download from BorgStack Service Prefixes"

    local dest="$DOWNLOAD_DIR/service-prefixes"
    mkdir -p "$dest"

    echo "Downloading from different service prefixes..."

    # Download from n8n
    echo ""
    echo "From n8n:"
    aws --endpoint-url "$S3_ENDPOINT" s3 sync "s3://$BUCKET/n8n/" "$dest/n8n/"

    # Download from Directus
    echo ""
    echo "From Directus:"
    aws --endpoint-url "$S3_ENDPOINT" s3 sync "s3://$BUCKET/directus/originals/" "$dest/directus/"

    # Download from FileFlows
    echo ""
    echo "From FileFlows:"
    aws --endpoint-url "$S3_ENDPOINT" s3 sync "s3://$BUCKET/fileflows/output/" "$dest/fileflows/"

    # Download from Chatwoot
    echo ""
    echo "From Chatwoot:"
    aws --endpoint-url "$S3_ENDPOINT" s3 sync "s3://$BUCKET/chatwoot/messages/" "$dest/chatwoot/"

    echo -e "${GREEN}✓${NC} Service prefix downloads completed"
    echo ""
    echo "Downloaded structure:"
    tree "$dest/" 2>/dev/null || find "$dest/" -type f
}

# Example 7: Download to stdout (pipe to other commands)
example_download_to_stdout() {
    print_section "Example 7: Download to stdout (Pipe)"

    echo "Downloading file content to stdout..."
    echo "Example: Count lines in remote file"

    LINE_COUNT=$(aws --endpoint-url "$S3_ENDPOINT" s3 cp "s3://$BUCKET/test/seaweedfs-test.txt" - | wc -l)

    echo -e "${GREEN}✓${NC} File has $LINE_COUNT lines"

    echo ""
    echo "Example: Search in remote file"
    echo "Searching for 'test' in file:"
    aws --endpoint-url "$S3_ENDPOINT" s3 cp "s3://$BUCKET/test/seaweedfs-test.txt" - | grep -i "test" || echo "No matches found"
}

# Example 8: Download with retry on failure
example_download_with_retry() {
    print_section "Example 8: Download with Retry Logic"

    local dest="$DOWNLOAD_DIR/retry-test"
    mkdir -p "$dest"
    local max_retries=3
    local retry_count=0

    echo "Downloading with retry logic (max $max_retries attempts)..."

    while [ $retry_count -lt $max_retries ]; do
        if aws --endpoint-url "$S3_ENDPOINT" s3 cp "s3://$BUCKET/test/seaweedfs-test.txt" "$dest/" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Download successful on attempt $((retry_count + 1))"
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                echo -e "${YELLOW}⚠${NC} Download failed, retrying... (attempt $((retry_count + 1))/$max_retries)"
                sleep 2
            else
                echo -e "❌ Download failed after $max_retries attempts"
                return 1
            fi
        fi
    done
}

# Example 9: List files before download
example_list_then_download() {
    print_section "Example 9: List Files Before Download"

    echo "Listing files in s3://$BUCKET/test/..."
    echo ""

    FILES=$(aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://$BUCKET/test/" --recursive)
    echo "$FILES"

    echo ""
    echo "Total files:"
    echo "$FILES" | wc -l

    local dest="$DOWNLOAD_DIR/list-then-download"
    mkdir -p "$dest"

    echo ""
    echo "Downloading all listed files..."
    aws --endpoint-url "$S3_ENDPOINT" s3 sync "s3://$BUCKET/test/" "$dest/"

    echo -e "${GREEN}✓${NC} All files downloaded"
}

# Example 10: Download with progress indicator
example_download_with_progress() {
    print_section "Example 10: Download Large File with Progress"

    local dest="$DOWNLOAD_DIR/large-file"
    mkdir -p "$dest"

    echo "Downloading large file (this will show progress)..."
    echo "Note: Progress is shown by default for files >50MB"

    if aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://$BUCKET/test/large-files/large-file.bin" > /dev/null 2>&1; then
        aws --endpoint-url "$S3_ENDPOINT" s3 cp "s3://$BUCKET/test/large-files/large-file.bin" "$dest/"
        echo -e "${GREEN}✓${NC} Large file downloaded"
        echo ""
        echo "File size:"
        ls -lh "$dest/large-file.bin"
    else
        echo -e "${YELLOW}⚠${NC} Large test file not found (run example-upload.sh first)"
    fi
}

# Main execution
main() {
    # Check prerequisites
    if ! command -v aws &> /dev/null; then
        echo "❌ Error: AWS CLI is not installed"
        echo "Install with: pip install awscli"
        exit 1
    fi

    if ! docker compose ps seaweedfs | grep -q "healthy"; then
        echo "❌ Error: SeaweedFS container is not healthy"
        echo "Start with: docker compose up -d seaweedfs"
        exit 1
    fi

    # Check if test files exist
    if ! aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://$BUCKET/test/" > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠${NC} Warning: Test files not found"
        echo "Run upload examples first: ./config/seaweedfs/example-upload.sh"
        echo ""
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    # Setup
    setup_download_dir

    # Run examples
    example_single_file
    example_multiple_files
    example_directory
    example_sync_download
    example_filtered_download
    example_service_prefixes
    example_download_to_stdout
    example_download_with_retry
    example_list_then_download
    example_download_with_progress

    # Summary
    print_section "Summary"
    echo -e "${GREEN}✓${NC} All download examples completed successfully"
    echo ""
    echo "Downloaded files location: $DOWNLOAD_DIR"
    echo ""
    echo "Directory structure:"
    du -sh "$DOWNLOAD_DIR"/* 2>/dev/null || echo "No files downloaded"
    echo ""
    echo "To clean up downloads:"
    echo "  rm -rf $DOWNLOAD_DIR"
    echo ""
    echo "For more information, see:"
    echo "  config/seaweedfs/README.md"
    echo "  docs/03-services/seaweedfs.md (Portuguese)"
    echo ""
}

# Run main function
main
