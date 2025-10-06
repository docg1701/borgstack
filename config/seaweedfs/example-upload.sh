#!/usr/bin/env bash
#
# SeaweedFS S3 Upload Examples
#
# This script demonstrates various file upload scenarios using AWS CLI with SeaweedFS.
# Before running, ensure AWS CLI is configured (run aws-cli-config.sh).
#
# Prerequisites:
#   1. AWS CLI installed and configured (./config/seaweedfs/aws-cli-config.sh)
#   2. SeaweedFS running and healthy (docker compose ps seaweedfs)
#   3. Bucket 'borgstack' exists (or run create_bucket function below)
#
# Usage:
#   ./config/seaweedfs/example-upload.sh
#
# Examples:
#   - Upload single file
#   - Upload multiple files
#   - Upload with metadata
#   - Upload entire directory
#   - Upload with custom content type
#   - Multipart upload for large files
#

set -euo pipefail

# SeaweedFS S3 endpoint
S3_ENDPOINT="http://localhost:8333"

# Main bucket
BUCKET="borgstack"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "SeaweedFS S3 Upload Examples"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
    echo ""
}

# Function to create bucket if it doesn't exist
create_bucket_if_not_exists() {
    print_section "Checking if bucket '$BUCKET' exists"

    if aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://$BUCKET" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Bucket '$BUCKET' already exists"
    else
        echo -e "${YELLOW}⚠${NC} Bucket '$BUCKET' does not exist. Creating..."
        aws --endpoint-url "$S3_ENDPOINT" s3 mb "s3://$BUCKET"
        echo -e "${GREEN}✓${NC} Bucket '$BUCKET' created successfully"
    fi
}

# Example 1: Upload a single file
example_single_file() {
    print_section "Example 1: Upload Single File"

    # Create a test file
    echo "This is a test file created at $(date)" > /tmp/seaweedfs-test.txt

    echo "Uploading /tmp/seaweedfs-test.txt to s3://$BUCKET/test/..."
    aws --endpoint-url "$S3_ENDPOINT" s3 cp /tmp/seaweedfs-test.txt "s3://$BUCKET/test/"

    echo -e "${GREEN}✓${NC} File uploaded successfully"
    echo ""
    echo "Verifying upload:"
    aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://$BUCKET/test/"
}

# Example 2: Upload multiple files
example_multiple_files() {
    print_section "Example 2: Upload Multiple Files"

    # Create test files
    mkdir -p /tmp/seaweedfs-upload-test
    echo "File 1 content" > /tmp/seaweedfs-upload-test/file1.txt
    echo "File 2 content" > /tmp/seaweedfs-upload-test/file2.txt
    echo "File 3 content" > /tmp/seaweedfs-upload-test/file3.txt

    echo "Uploading 3 files to s3://$BUCKET/test/multiple/..."
    aws --endpoint-url "$S3_ENDPOINT" s3 sync /tmp/seaweedfs-upload-test/ "s3://$BUCKET/test/multiple/"

    echo -e "${GREEN}✓${NC} Files uploaded successfully"
    echo ""
    echo "Verifying uploads:"
    aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://$BUCKET/test/multiple/"

    # Cleanup
    rm -rf /tmp/seaweedfs-upload-test
}

# Example 3: Upload with metadata
example_with_metadata() {
    print_section "Example 3: Upload with Custom Metadata"

    # Create a test file
    echo '{"name": "John Doe", "email": "john@example.com"}' > /tmp/user-data.json

    echo "Uploading file with metadata..."
    aws --endpoint-url "$S3_ENDPOINT" s3 cp /tmp/user-data.json "s3://$BUCKET/test/metadata/" \
        --metadata author="BorgStack",department="Engineering",version="1.0" \
        --content-type "application/json"

    echo -e "${GREEN}✓${NC} File uploaded with metadata"
    echo ""
    echo "Retrieving file metadata:"
    aws --endpoint-url "$S3_ENDPOINT" s3api head-object \
        --bucket "$BUCKET" \
        --key "test/metadata/user-data.json" \
        --query '{ContentType:ContentType,Metadata:Metadata}' || echo "Note: Metadata retrieval may require s3api support"
}

# Example 4: Upload entire directory with sync
example_directory_sync() {
    print_section "Example 4: Upload Directory with Sync"

    # Create test directory structure
    mkdir -p /tmp/seaweedfs-dir-test/images
    mkdir -p /tmp/seaweedfs-dir-test/documents
    echo "Image 1" > /tmp/seaweedfs-dir-test/images/img1.jpg
    echo "Image 2" > /tmp/seaweedfs-dir-test/images/img2.jpg
    echo "Document 1" > /tmp/seaweedfs-dir-test/documents/doc1.pdf

    echo "Syncing directory to s3://$BUCKET/test/directory/..."
    aws --endpoint-url "$S3_ENDPOINT" s3 sync /tmp/seaweedfs-dir-test/ "s3://$BUCKET/test/directory/"

    echo -e "${GREEN}✓${NC} Directory synced successfully"
    echo ""
    echo "Directory structure in S3:"
    aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://$BUCKET/test/directory/" --recursive

    # Cleanup
    rm -rf /tmp/seaweedfs-dir-test
}

# Example 5: Upload with specific content type
example_content_type() {
    print_section "Example 5: Upload with Content Type"

    # Create test files with different types
    echo "<html><body>Hello World</body></html>" > /tmp/test.html
    echo '{"test": true}' > /tmp/test.json
    echo "Plain text file" > /tmp/test.txt

    echo "Uploading files with correct content types..."
    aws --endpoint-url "$S3_ENDPOINT" s3 cp /tmp/test.html "s3://$BUCKET/test/content-types/" \
        --content-type "text/html"

    aws --endpoint-url "$S3_ENDPOINT" s3 cp /tmp/test.json "s3://$BUCKET/test/content-types/" \
        --content-type "application/json"

    aws --endpoint-url "$S3_ENDPOINT" s3 cp /tmp/test.txt "s3://$BUCKET/test/content-types/" \
        --content-type "text/plain"

    echo -e "${GREEN}✓${NC} Files uploaded with content types"
    echo ""
    echo "Uploaded files:"
    aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://$BUCKET/test/content-types/"
}

# Example 6: Upload large file (simulated)
example_large_file() {
    print_section "Example 6: Large File Upload (Multipart)"

    echo "Creating a 50MB test file..."
    dd if=/dev/zero of=/tmp/large-file.bin bs=1M count=50 > /dev/null 2>&1

    echo "Uploading large file (this will use multipart upload)..."
    echo "Note: Files >15MB automatically use multipart upload"
    aws --endpoint-url "$S3_ENDPOINT" s3 cp /tmp/large-file.bin "s3://$BUCKET/test/large-files/"

    echo -e "${GREEN}✓${NC} Large file uploaded successfully"
    echo ""
    echo "Verifying upload:"
    aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://$BUCKET/test/large-files/" --human-readable

    # Cleanup
    rm /tmp/large-file.bin
}

# Example 7: Upload to BorgStack service prefixes
example_borgstack_prefixes() {
    print_section "Example 7: Upload to BorgStack Service Prefixes"

    echo "Uploading files to different service prefixes..."

    # n8n workflow attachment
    echo "n8n attachment" > /tmp/n8n-file.txt
    aws --endpoint-url "$S3_ENDPOINT" s3 cp /tmp/n8n-file.txt "s3://$BUCKET/n8n/"

    # Directus CMS asset
    echo "Directus asset" > /tmp/directus-asset.jpg
    aws --endpoint-url "$S3_ENDPOINT" s3 cp /tmp/directus-asset.jpg "s3://$BUCKET/directus/originals/"

    # FileFlows output
    echo "Processed media" > /tmp/processed-video.mp4
    aws --endpoint-url "$S3_ENDPOINT" s3 cp /tmp/processed-video.mp4 "s3://$BUCKET/fileflows/output/"

    # Chatwoot attachment
    echo "Chat attachment" > /tmp/chat-file.pdf
    aws --endpoint-url "$S3_ENDPOINT" s3 cp /tmp/chat-file.pdf "s3://$BUCKET/chatwoot/messages/"

    echo -e "${GREEN}✓${NC} Files uploaded to service prefixes"
    echo ""
    echo "BorgStack bucket structure:"
    aws --endpoint-url "$S3_ENDPOINT" s3 ls "s3://$BUCKET/" --recursive | head -20
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

    # Create bucket if needed
    create_bucket_if_not_exists

    # Run examples
    example_single_file
    example_multiple_files
    example_with_metadata
    example_directory_sync
    example_content_type
    example_large_file
    example_borgstack_prefixes

    # Summary
    print_section "Summary"
    echo -e "${GREEN}✓${NC} All upload examples completed successfully"
    echo ""
    echo "To view all uploaded files:"
    echo "  aws --endpoint-url $S3_ENDPOINT s3 ls s3://$BUCKET/ --recursive"
    echo ""
    echo "To delete test files:"
    echo "  aws --endpoint-url $S3_ENDPOINT s3 rm s3://$BUCKET/test/ --recursive"
    echo ""
    echo "For download examples, see:"
    echo "  ./config/seaweedfs/example-download.sh"
    echo ""
}

# Run main function
main
