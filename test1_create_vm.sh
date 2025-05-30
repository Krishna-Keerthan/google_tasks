# =================================================================
# PRACTICAL TEST 1 - Deploy a Single VM (IMPROVED)
# =================================================================

#!/bin/bash
# test1_create_vm_improved.sh

PROJECT_ID="your-project-id"
ZONE="us-central1-a"
VM_NAME="web-server-$(date +%s)"
MACHINE_TYPE="e2-standard-4"  # 4 vCPUs, 16GB RAM for 200 concurrent users
IMAGE_FAMILY="debian-11"
IMAGE_PROJECT="debian-cloud"
TAGS="http-server,https-server"
DISK_SIZE="50GB"
DISK_TYPE="pd-standard"

echo "Creating VM with high availability and HTTP/HTTPS access..."

# Set project
gcloud config set project $PROJECT_ID

# Enable Compute Engine API if not enabled
gcloud services enable compute.googleapis.com

# Create VM with enhanced configuration for production use
gcloud compute instances create $VM_NAME \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --image-family=$IMAGE_FAMILY \
  --image-project=$IMAGE_PROJECT \
  --tags=$TAGS \
  --restart-on-failure \
  --maintenance-policy=MIGRATE \
  --boot-disk-size=$DISK_SIZE \
  --boot-disk-type=$DISK_TYPE \
  --boot-disk-device-name=$VM_NAME \
  --metadata=startup-script='#!/bin/bash
# Update system
apt update && apt upgrade -y

# Install Apache2 and configure for high availability
apt install -y apache2 apache2-utils

# Configure Apache for better performance
cat > /etc/apache2/conf-available/performance.conf << EOF
# Performance tuning for 200 concurrent users
ServerLimit 8
MaxRequestWorkers 400
ThreadsPerChild 50
MinSpareThreads 25
MaxSpareThreads 75
ThreadLimit 64
EOF

a2enconf performance
systemctl enable apache2
systemctl start apache2

# Create a basic status page
echo "<h1>Web Server Status: OK</h1><p>Server: $(hostname)</p><p>Time: $(date)</p>" > /var/www/html/status.html

# Configure log rotation
cat > /etc/logrotate.d/apache2-custom << EOF
/var/log/apache2/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    create 644 root adm
    postrotate
        systemctl reload apache2
    endscript
}
EOF

echo "VM setup completed at $(date)" >> /var/log/vm-setup.log'

# Create firewall rules with specific source ranges for security
gcloud compute firewall-rules create allow-web-traffic-$VM_NAME \
  --allow tcp:80,tcp:443 \
  --target-tags=$TAGS \
  --source-ranges=0.0.0.0/0 \
  --description="Allow HTTP and HTTPS traffic for $VM_NAME"

# Optional: Create a health check firewall rule for load balancers
gcloud compute firewall-rules create allow-health-check-$VM_NAME \
  --allow tcp:80 \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 \
  --target-tags=$TAGS \
  --description="Allow health check traffic"

# Wait for VM to be ready
echo "Waiting for VM to be ready..."
sleep 30

# Get external IP
EXTERNAL_IP=$(gcloud compute instances describe $VM_NAME --zone=$ZONE --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

echo "VM deployment completed successfully!"
echo "VM Name: $VM_NAME"
echo "Zone: $ZONE"
echo "Machine Type: $MACHINE_TYPE"
echo "External IP: $EXTERNAL_IP"
echo "Access URL: http://$EXTERNAL_IP"
echo "Status URL: http://$EXTERNAL_IP/status.html"

# Save deployment info for cleanup
echo "VM_NAME=$VM_NAME" > test1_deployment.env
echo "FIREWALL_RULE_1=allow-web-traffic-$VM_NAME" >> test1_deployment.env
echo "FIREWALL_RULE_2=allow-health-check-$VM_NAME" >> test1_deployment.env
