# =================================================================
# PRACTICAL TEST 3 - Secure Cloud Storage Bucket (IMPROVED)
# =================================================================

#!/bin/bash
# test3_secure_bucket.sh

PROJECT_ID="your-project-id"
TIMESTAMP=$(date +%s)
BUCKET_NAME="secure-image-bucket-$TIMESTAMP"
REGION="us-central1"
SERVICE_ACCOUNT_NAME="storage-access-sa-$TIMESTAMP"
SERVICE_ACCOUNT_EMAIL="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"
STORAGE_CLASS="STANDARD"

echo "Creating secure Cloud Storage bucket with restricted access..."

gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable storage-api.googleapis.com iam.googleapis.com storage.googleapis.com

# Create service account for application access
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
  --display-name="Storage Access Service Account" \
  --description="Service account for secure bucket access"

# Wait for service account to be fully created
sleep 10

# Create the bucket with specific configuration
gsutil mb -c $STORAGE_CLASS -l $REGION gs://$BUCKET_NAME/

# Enable uniform bucket-level access (modern approach)
gsutil uniformbucketlevelaccess set on gs://$BUCKET_NAME

# Set bucket lifecycle policy for cost optimization
cat > lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {"age": 30}
      },
      {
        "action": {"type": "Delete"},
        "condition": {"age": 365}
      }
    ]
  }
}
EOF

gsutil lifecycle set lifecycle.json gs://$BUCKET_NAME

# Remove all public access
gsutil iam ch -d allUsers:objectViewer gs://$BUCKET_NAME/ 2>/dev/null || true
gsutil iam ch -d allAuthenticatedUsers:objectViewer gs://$BUCKET_NAME/ 2>/dev/null || true

# Grant specific permissions to service account
gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_EMAIL:objectCreator gs://$BUCKET_NAME/
gsutil iam ch serviceAccount:$SERVICE_ACCOUNT_EMAIL:objectViewer gs://$BUCKET_NAME/

# Set bucket-level IAM policy for additional security
cat > bucket-policy.json << EOF
{
  "bindings": [
    {
      "role": "roles/storage.objectAdmin",
      "members": [
        "serviceAccount:$SERVICE_ACCOUNT_EMAIL"
      ]
    }
  ]
}
EOF

gsutil iam set bucket-policy.json gs://$BUCKET_NAME/

# Configure CORS for web application (if needed)
cat > cors.json << EOF
[
  {
    "origin": ["*"],
    "method": ["GET", "POST", "PUT"],
    "responseHeader": ["Content-Type", "x-goog-resumable"],
    "maxAgeSeconds": 3600
  }
]
EOF

gsutil cors set cors.json gs://$BUCKET_NAME

# Test upload with service account (create test file)
echo "Test file created at $(date)" > test-upload.txt
gsutil cp test-upload.txt gs://$BUCKET_NAME/test/

# Verify security settings
echo "Verifying bucket configuration..."
gsutil ls -L -b gs://$BUCKET_NAME/ | grep -E "(Location|Storage class|Public access prevention)"

# Clean up temporary files
rm -f lifecycle.json bucket-policy.json cors.json test-upload.txt

echo "Secure bucket created successfully!"
echo "Bucket name: $BUCKET_NAME"
echo "Service account: $SERVICE_ACCOUNT_EMAIL"
echo "Region: $REGION"
echo "Storage class: $STORAGE_CLASS"

# Save deployment info for cleanup
cat > test3_deployment.env << EOF
BUCKET_NAME=$BUCKET_NAME
SERVICE_ACCOUNT_NAME=$SERVICE_ACCOUNT_NAME
SERVICE_ACCOUNT_EMAIL=$SERVICE_ACCOUNT_EMAIL
EOF
