# =================================================================
# CLEANUP SCRIPT FOR TEST 4 - Cloud SQL with Secret Manager (IMPROVED)
# =================================================================

#!/bin/bash
# cleanup_test4.sh

PROJECT_ID="your-project-id"

echo "Cleaning up Test 4 resources..."
gcloud config set project $PROJECT_ID

# Load deployment environment variables if available
if [ -f "test4_deployment.env" ]; then
    source test4_deployment.env
    echo "Found deployment configuration"
else
    echo "Warning: No deployment configuration found, using pattern matching"
fi

# Delete Cloud SQL instances
echo "Deleting Cloud SQL instances..."
if [ ! -z "$INSTANCE_NAME" ]; then
    # Remove deletion protection first
    gcloud sql instances patch $INSTANCE_NAME --no-deletion-protection --quiet 2>/dev/null
    sleep 10
    gcloud sql instances delete $INSTANCE_NAME --quiet 2>/dev/null
    echo "Deleted SQL instance: $INSTANCE_NAME"
else
    for instance in $(gcloud sql instances list --filter="name~'prod-mysql-instance'" --format="value(name)"); do
        gcloud sql instances patch $instance --no-deletion-protection --quiet 2>/dev/null
        sleep 10
        gcloud sql instances delete $instance --quiet 2>/dev/null
        echo "Deleted SQL instance: $instance"
    done
fi

# Delete secrets
echo "Deleting secrets..."
if [ ! -z "$SECRET_ID" ]; then
    gcloud secrets delete $SECRET_ID --quiet 2>/dev/null
    echo "Deleted secret: $SECRET_ID"
else
    for secret in $(gcloud secrets list --filter="name~'db-credentials'" --format="value(name)"); do
        gcloud secrets delete $secret --quiet 2>/dev/null
        echo "Deleted secret: $secret"
    done
fi

# Delete service accounts
echo "Deleting service accounts..."
if [ ! -z "$SERVICE_ACCOUNT" ]; then
    gcloud iam service-accounts delete $SERVICE_ACCOUNT --quiet 2>/dev/null
    echo "Deleted service account: $SERVICE_ACCOUNT"
else
    for sa in $(gcloud iam service-accounts list --filter="email~'app-service-account'" --format="value(email)"); do
        gcloud iam service-accounts delete $sa --quiet 2>/dev/null
        echo "Deleted service account: $sa"
    done
fi

# Remove test files
rm -f test_connection.sh

# Remove deployment configuration
rm -f test4_deployment.env

echo "Test 4 cleanup completed!"
