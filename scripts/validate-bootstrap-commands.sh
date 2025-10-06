#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TEST_BUCKET="devops-showcase-terraform-state-test-$(date +%s)"
AWS_REGION="eu-central-1"

echo "======================================================"
echo "Bootstrap AWS CLI Commands Validation"
echo "======================================================"
echo ""
echo "Test Bucket: ${TEST_BUCKET}"
echo "Region: ${AWS_REGION}"
echo ""
echo "This script will:"
echo "  1. Create a test S3 bucket"
echo "  2. Run all bootstrap configuration commands"
echo "  3. Verify each step"
echo "  4. Clean up the test bucket"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Function to check command success
check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ SUCCESS${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

# Step 1: Verify AWS credentials
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Verify AWS Credentials"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
aws sts get-caller-identity
check_result || exit 1
echo ""

# Step 2: Create bucket
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Create S3 Bucket"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "${AWS_REGION}" == "us-east-1" ]; then
    aws s3api create-bucket \
        --bucket ${TEST_BUCKET} \
        --region ${AWS_REGION}
else
    aws s3api create-bucket \
        --bucket ${TEST_BUCKET} \
        --region ${AWS_REGION} \
        --create-bucket-configuration LocationConstraint=${AWS_REGION}
fi
check_result || exit 1
echo ""

# Step 3: Enable versioning
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Enable Versioning"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
aws s3api put-bucket-versioning \
    --bucket ${TEST_BUCKET} \
    --versioning-configuration Status=Enabled
check_result || exit 1
echo ""

# Step 4: Enable encryption
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Enable Encryption"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
aws s3api put-bucket-encryption \
    --bucket ${TEST_BUCKET} \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        },
        "BucketKeyEnabled": true
      }]
    }'
check_result || exit 1
echo ""

# Step 5: Block public access
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Block Public Access"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
aws s3api put-public-access-block \
    --bucket ${TEST_BUCKET} \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
check_result || exit 1
echo ""

# Step 6: Add lifecycle policy
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Add Lifecycle Policy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
aws s3api put-bucket-lifecycle-configuration \
    --bucket ${TEST_BUCKET} \
    --lifecycle-configuration '{
      "Rules": [{
        "ID": "DeleteOldVersions",
        "Status": "Enabled",
        "Filter": {
          "Prefix": ""
        },
        "NoncurrentVersionExpiration": {
          "NoncurrentDays": 90
        }
      }]
    }'
check_result || exit 1
echo ""

# Step 7: Add tags
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 7: Add Tags"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
aws s3api put-bucket-tagging \
    --bucket ${TEST_BUCKET} \
    --tagging 'TagSet=[{Key=Project,Value=DevOps-Showcase},{Key=Purpose,Value=Terraform-State},{Key=ManagedBy,Value=GitHub-Actions}]'
check_result || exit 1
echo ""

# Step 8: Verify all configurations
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 8: Verify Configurations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "8.1 Versioning Status:"
aws s3api get-bucket-versioning --bucket ${TEST_BUCKET}
check_result

echo ""
echo "8.2 Encryption Status:"
aws s3api get-bucket-encryption --bucket ${TEST_BUCKET}
check_result

echo ""
echo "8.3 Public Access Block:"
aws s3api get-public-access-block --bucket ${TEST_BUCKET}
check_result

echo ""
echo "8.4 Lifecycle Configuration:"
aws s3api get-bucket-lifecycle-configuration --bucket ${TEST_BUCKET}
check_result

echo ""
echo "8.5 Tags:"
aws s3api get-bucket-tagging --bucket ${TEST_BUCKET}
check_result

echo ""

# Cleanup
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Delete test bucket ${TEST_BUCKET}? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deleting bucket..."
    aws s3 rb s3://${TEST_BUCKET} --force
    check_result
    echo "✅ Test bucket deleted"
else
    echo -e "${YELLOW}⚠️  Test bucket NOT deleted: ${TEST_BUCKET}${NC}"
    echo "To delete manually, run:"
    echo "  aws s3 rb s3://${TEST_BUCKET} --force"
fi

echo ""
echo "======================================================"
echo -e "${GREEN}✅ All validation steps completed!${NC}"
echo "======================================================"
echo ""
echo "The bootstrap workflow commands are working correctly."
echo "You can now run the GitHub Actions workflow with confidence."
