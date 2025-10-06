#!/bin/bash

# Bootstrap script to create S3 bucket and DynamoDB table for Terraform state
# Run this ONCE before deploying the main infrastructure

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Terraform State Backend Bootstrap                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
PROJECT_NAME="${PROJECT_NAME:-devops-showcase}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

BUCKET_NAME="${PROJECT_NAME}-${ENVIRONMENT}-tfstate-${AWS_ACCOUNT_ID}"

echo "Configuration:"
echo "  AWS Account ID: $AWS_ACCOUNT_ID"
echo "  Region: $AWS_REGION"
echo "  S3 Bucket: $BUCKET_NAME"
echo ""

# Check if bucket already exists
if aws s3 ls "s3://${BUCKET_NAME}" 2>/dev/null; then
    echo "✅ S3 bucket already exists: ${BUCKET_NAME}"
else
    echo "📦 Creating S3 bucket for Terraform state..."
    
    # Create bucket
    if [ "$AWS_REGION" = "eu-central-1" ]; then
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}"
    else
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi
    
    # Enable versioning
    echo "🔄 Enabling versioning..."
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    echo "🔒 Enabling encryption..."
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }]
        }'
    
    # Block public access
    echo "🚫 Blocking public access..."
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    # Add lifecycle policy to clean up old versions
    echo "♻️  Adding lifecycle policy..."
    aws s3api put-bucket-lifecycle-configuration \
        --bucket "${BUCKET_NAME}" \
        --lifecycle-configuration '{
            "Rules": [{
                "Id": "DeleteOldVersions",
                "Status": "Enabled",
                "NoncurrentVersionExpiration": {
                    "NoncurrentDays": 90
                }
            }]
        }'
    
    echo "✅ S3 bucket created successfully"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Bootstrap Complete!                                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📝 Update your terraform/providers.tf with:"
echo ""
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket  = \"${BUCKET_NAME}\""
echo "    key     = \"terraform.tfstate\""
echo "    region  = \"${AWS_REGION}\""
echo "    encrypt = true"
echo "  }"
echo "}"
echo ""
echo "Then run:"
echo "  cd terraform"
echo "  terraform init -reconfigure"
echo ""
echo "Note: S3 now provides native state locking - no DynamoDB needed!"
echo ""
