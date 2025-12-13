#!/bin/bash
set -e # Stop script if any command fails

# --- CONFIGURATION ---
# CHANGE THIS to a unique name (e.g., shopfast-state-rajkumar-2025)
BUCKET_NAME="shopfast-state-rajkumar-2025" 
TABLE_NAME="shopfast-locks"
REGION="us-east-1"

echo "Using Bucket: $BUCKET_NAME"
echo "Using Table: $TABLE_NAME"

# 1. Create S3 Bucket
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Bucket $BUCKET_NAME already exists."
else
    echo "Creating S3 Bucket..."
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
    
    # Enable Versioning (Crucial for rollback)
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
    echo "Bucket created and versioning enabled."
fi

# 2. Create DynamoDB Table for Locking
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "Table $TABLE_NAME already exists."
else
    echo "Creating DynamoDB Table..."
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$REGION"
    echo "DynamoDB Table created."
fi

echo "✅ Bootstrap complete! You are ready for Terraform."
