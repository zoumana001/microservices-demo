#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# bootstrap.sh
# Run this ONCE before "terraform init" to create the S3
# remote backend and DynamoDB lock table for zoum_cluster.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

REGION="us-east-1"
BUCKET="zoum-terraform-state"
DYNAMO_TABLE="zoum-terraform-locks"

echo "==> Creating S3 state bucket: $BUCKET"
aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$REGION"

echo "==> Enabling versioning"
aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

echo "==> Enabling AES-256 encryption"
aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration '{
    "Rules":[{
      "ApplyServerSideEncryptionByDefault":{
        "SSEAlgorithm":"AES256"
      }
    }]
  }'

echo "==> Blocking all public access"
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "==> Creating DynamoDB lock table: $DYNAMO_TABLE"
aws dynamodb create-table \
  --table-name "$DYNAMO_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

echo ""
echo "✓ Bootstrap complete. Now run:"
echo "  cd envs/prod && terraform init"
