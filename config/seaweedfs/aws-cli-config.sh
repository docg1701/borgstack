#!/usr/bin/env bash
#
# AWS CLI Configuration for SeaweedFS S3 API
#
# This script configures the AWS CLI to work with SeaweedFS S3-compatible API.
# Run this script after installing AWS CLI and generating SeaweedFS credentials.
#
# Prerequisites:
#   1. AWS CLI installed: https://aws.amazon.com/cli/
#   2. SeaweedFS credentials generated (openssl rand -base64 24/48)
#   3. Credentials added to .env file
#
# Usage:
#   source ./config/seaweedfs/aws-cli-config.sh
#   OR
#   ./config/seaweedfs/aws-cli-config.sh
#
# After configuration, test with:
#   aws --endpoint-url http://localhost:8333 s3 ls
#

set -euo pipefail

# Navigate to project root
cd "$(dirname "$0")/../.."

# Load environment variables from .env
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found"
    echo "Please create .env file with SEAWEEDFS_ACCESS_KEY and SEAWEEDFS_SECRET_KEY"
    exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

# Verify credentials are set
if [ -z "${SEAWEEDFS_ACCESS_KEY:-}" ] || [ -z "${SEAWEEDFS_SECRET_KEY:-}" ]; then
    echo "❌ Error: SeaweedFS credentials not found in .env"
    echo ""
    echo "Please add the following to your .env file:"
    echo ""
    echo "# Generate credentials:"
    echo "# Access Key: openssl rand -base64 24"
    echo "# Secret Key: openssl rand -base64 48"
    echo ""
    echo "SEAWEEDFS_ACCESS_KEY=<your-access-key>"
    echo "SEAWEEDFS_SECRET_KEY=<your-secret-key>"
    echo ""
    exit 1
fi

echo "Configuring AWS CLI for SeaweedFS S3 API..."
echo ""

# Configure AWS CLI
echo "Setting AWS access key ID..."
aws configure set aws_access_key_id "${SEAWEEDFS_ACCESS_KEY}"

echo "Setting AWS secret access key..."
aws configure set aws_secret_access_key "${SEAWEEDFS_SECRET_KEY}"

echo "Setting default region (us-east-1)..."
aws configure set default.region us-east-1

echo "Setting S3 signature version (s3v4)..."
aws configure set default.s3.signature_version s3v4

echo ""
echo "✅ AWS CLI configured successfully!"
echo ""
echo "Configuration details:"
echo "  Access Key: ${SEAWEEDFS_ACCESS_KEY:0:8}...${SEAWEEDFS_ACCESS_KEY: -4}"
echo "  Region: us-east-1"
echo "  Signature: s3v4"
echo ""
echo "Testing connection..."

# Test connection
if docker compose ps seaweedfs | grep -q "healthy"; then
    echo "✅ SeaweedFS container is healthy"
    echo ""
    echo "Testing S3 API access..."

    if aws --endpoint-url http://localhost:8333 s3 ls > /dev/null 2>&1; then
        echo "✅ S3 API connection successful!"
        echo ""
        echo "Available buckets:"
        aws --endpoint-url http://localhost:8333 s3 ls
    else
        echo "⚠️  S3 API test failed. This may be normal if no buckets exist yet."
        echo "Create a bucket with:"
        echo "  aws --endpoint-url http://localhost:8333 s3 mb s3://borgstack"
    fi
else
    echo "❌ SeaweedFS container is not healthy"
    echo "Start SeaweedFS with: docker compose up -d seaweedfs"
    exit 1
fi

echo ""
echo "Next steps:"
echo ""
echo "1. List buckets:"
echo "   aws --endpoint-url http://localhost:8333 s3 ls"
echo ""
echo "2. Create bucket:"
echo "   aws --endpoint-url http://localhost:8333 s3 mb s3://borgstack"
echo ""
echo "3. Upload file:"
echo "   aws --endpoint-url http://localhost:8333 s3 cp myfile.txt s3://borgstack/test/"
echo ""
echo "4. List files in bucket:"
echo "   aws --endpoint-url http://localhost:8333 s3 ls s3://borgstack/"
echo ""
echo "5. Download file:"
echo "   aws --endpoint-url http://localhost:8333 s3 cp s3://borgstack/test/myfile.txt ./"
echo ""
echo "For more examples, see:"
echo "  - config/seaweedfs/example-upload.sh"
echo "  - config/seaweedfs/example-download.sh"
echo "  - config/seaweedfs/README.md"
echo ""
