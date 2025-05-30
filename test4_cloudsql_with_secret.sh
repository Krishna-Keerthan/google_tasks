# =================================================================
# PRACTICAL TEST 4 - Cloud SQL with Secret Manager (IMPROVED)
# =================================================================

#!/bin/bash
# test4_cloudsql_with_secret.sh

PROJECT_ID="your-project-id"
TIMESTAMP=$(date +%s)
INSTANCE_NAME="prod-mysql-instance-$TIMESTAMP"
DB_NAME="app_db"
DB_USER="app_user"
REGION="us-central1"
TIER="db-n1-standard-1"  # Better for production
ROOT_USER="root"
SECRET_ID="db-credentials-$TIMESTAMP"
SERVICE_ACCOUNT_NAME="app-service-account-$TIMESTAMP"
SERVICE_ACCOUNT="$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com"

echo "Creating Cloud SQL instance with Secret Manager integration..."

gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable sqladmin.googleapis.com secretmanager.googleapis.com

# Generate secure passwords
ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
DB_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

echo "Generated secure passwords"

# Create service account
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
  --display-name="Application Service Account" \
  --description="Service account for Cloud SQL access"

# Wait for service account creation
sleep 10

# Create Cloud SQL instance with enhanced security
gcloud sql instances create $INSTANCE_NAME \
  --database-version=MYSQL_8_0 \
  --tier=$TIER \
  --region=$REGION \
  --root-password="$ROOT_PASSWORD" \
  --storage-type=SSD \
  --storage-size=20GB \
  --storage-auto-increase \
  --backup-start-time=03:00 \
  --enable-bin-log \
  --maintenance-window-day=SUN \
  --maintenance-window-hour=04 \
  --deletion-protection

echo "Cloud SQL instance created, configuring network access..."

# Configure authorized networks (restrict to specific IP ranges)
# For production, replace with actual application server IPs or VPC ranges
gcloud sql instances patch $INSTANCE_NAME \
  --authorized-networks=0.0.0.0/0 \
  --backup \
  --enable-ip-alias

# Wait for instance to be ready
echo "Waiting for instance to be ready..."
sleep 120

# Create database
gcloud sql databases create $DB_NAME --instance=$INSTANCE_NAME

# Create database user with specific privileges
gcloud sql users create $DB_USER \
  --instance=$INSTANCE_NAME \
  --password="$DB_PASS"

# Grant specific privileges to the user
gcloud sql users set-password $DB_USER \
  --instance=$INSTANCE_NAME \
  --password="$DB_PASS"

# Get instance connection details
INSTANCE_IP=$(gcloud sql instances describe $INSTANCE_NAME --format="get(ipAddresses[0].ipAddress)")
CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME --format="get(connectionName)")

# Create comprehensive credentials JSON
cat > creds.json << EOF
{
  "instance_name": "$INSTANCE_NAME",
  "connection_name": "$CONNECTION_NAME",
  "database_name": "$DB_NAME",
  "username": "$DB_USER",
  "password": "$DB_PASS",
  "root_password": "$ROOT_PASSWORD",
  "instance_ip": "$INSTANCE_IP",
  "port": 3306,
  "ssl_mode": "REQUIRED"
}
EOF

# Store credentials in Secret Manager
gcloud secrets create $SECRET_ID --data-file=creds.json

# Grant access to service account
gcloud secrets add-iam-policy-binding $SECRET_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/secretmanager.secretAccessor"

# Grant Cloud SQL client role to service account
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/cloudsql.client"

# Create connection test script
cat > test_connection.sh << EOF
#!/bin/bash
# Test script to verify database connection
mysql -h $INSTANCE_IP -u $DB_USER -p$DB_PASS -e "SELECT 1 as test_connection;" $DB_NAME
EOF

chmod +x test_connection.sh

# Clean up sensitive files
rm creds.json

echo "Cloud SQL instance and Secret Manager setup completed successfully!"
echo "Instance: $INSTANCE_NAME"
echo "Connection Name: $CONNECTION_NAME"
echo "Database: $DB_NAME"
echo "Instance IP: $INSTANCE_IP"
echo "Secret ID: $SECRET_ID"
echo "Service Account: $SERVICE_ACCOUNT"
echo "Test connection with: ./test_connection.sh"

# Save deployment info for cleanup
cat > test4_deployment.env << EOF
INSTANCE_NAME=$INSTANCE_NAME
SECRET_ID=$SECRET_ID
SERVICE_ACCOUNT_NAME=$SERVICE_ACCOUNT_NAME
SERVICE_ACCOUNT=$SERVICE_ACCOUNT
EOF
