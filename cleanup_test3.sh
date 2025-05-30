# =================================================================
# CLEANUP SCRIPT FOR TEST 3 - Secure Storage Bucket (IMPROVED)
# =================================================================

#!/bin/bash
# cleanup_test3.sh

PROJECT_ID="your-project-id"

echo "Cleaning up Test 3 resources..."
gcloud config set project $PROJECT_ID

# Load deployment environment variables if available
if [ -f "test3_deployment.env" ]; then
    source test3_deployment.env
    echo "Found deployment configuration"
else
    echo "Warning: No deployment configuration found, using pattern matching"
fi

# Delete bucket contents and bucket
echo "Deleting Cloud Storage buckets..."
if [ ! -z "$BUCKET_NAME" ]; then
    echo "Emptying bucket: $BUCKET_NAME"
    gsutil -m rm -r gs://$BUCKET_NAME/** 2>/dev/null || true
    gsutil rb gs://$BUCKET_NAME/ 2>/dev/null
    echo "Deleted bucket: $BUCKET_NAME"
else
    # Find and delete buckets with pattern
    for bucket in $(gsutil ls | grep "secure-image-bucket" | sed 's/gs:\/\///' | sed 's/\///'); do
        echo "Emptying bucket: $bucket"
        gsutil -m rm -r gs://$bucket/** 2>/dev/null || true
        gsutil rb gs://$bucket/ 2>/dev/null
        echo "Deleted bucket: $bucket"
    done
fi

# Delete service accounts
echo "Deleting service accounts..."
if [ ! -z "$SERVICE_ACCOUNT_EMAIL" ]; then
    gcloud iam service-accounts delete $SERVICE_ACCOUNT_EMAIL --quiet 2>/dev/null
    echo "Deleted service account: $SERVICE_ACCOUNT_EMAIL"
else
    # Find and delete service accounts with pattern
    for sa in $(gcloud iam service-accounts list --filter="email~'storage-access-sa'" --format="value(email)"); do
        gcloud iam service-accounts delete $sa --quiet 2>/dev/null
        echo "Deleted service account: $sa"
    done
fi

# Remove deployment configuration
rm -f test3_deployment.env

echo "Test 3 cleanup completed!"
