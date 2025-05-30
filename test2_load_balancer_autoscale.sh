# =================================================================
# PRACTICAL TEST 2 - Load Balancer and Auto-scaling (IMPROVED)
# =================================================================

#!/bin/bash
# test2_load_balancer_autoscale_improved.sh

PROJECT_ID="your-project-id"
ZONE="us-central1-a"
REGION="us-central1"
TIMESTAMP=$(date +%s)
INSTANCE_TEMPLATE="web-instance-template-$TIMESTAMP"
INSTANCE_GROUP="web-instance-group-$TIMESTAMP"
HEALTH_CHECK="web-health-check-$TIMESTAMP"
BACKEND_SERVICE="web-backend-service-$TIMESTAMP"
URL_MAP="web-url-map-$TIMESTAMP"
HTTP_PROXY="web-http-proxy-$TIMESTAMP"
FORWARDING_RULE="web-forwarding-rule-$TIMESTAMP"
MACHINE_TYPE="e2-medium"
VM_TAG="http-server-lb"

echo "Creating managed instance group with HTTP load balancer..."

gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com

# Create instance template with improved startup script
gcloud compute instance-templates create $INSTANCE_TEMPLATE \
  --machine-type=$MACHINE_TYPE \
  --tags=$VM_TAG \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --boot-disk-size=20GB \
  --boot-disk-type=pd-standard \
  --metadata=startup-script='#!/bin/bash
# Update system
apt update && apt upgrade -y

# Install Apache and stress testing tools
apt install -y apache2 stress-ng

# Configure Apache for load balancing
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head><title>Load Balanced Server</title></head>
<body>
<h1>Welcome to $(hostname)</h1>
<p>Server IP: $(hostname -I)</p>
<p>Time: $(date)</p>
<p>Load: $(uptime)</p>
</body>
</html>
EOF

# Create health check endpoint
cat > /var/www/html/health << EOF
OK
EOF

# Enable and start Apache
systemctl enable apache2
systemctl start apache2

# Log startup completion
echo "Instance $(hostname) ready at $(date)" >> /var/log/startup.log'

# Create managed instance group
gcloud compute instance-groups managed create $INSTANCE_GROUP \
  --base-instance-name=web-server \
  --template=$INSTANCE_TEMPLATE \
  --size=2 \
  --zone=$ZONE

# Configure autoscaling with optimized settings
gcloud compute instance-groups managed set-autoscaling $INSTANCE_GROUP \
  --zone=$ZONE \
  --max-num-replicas=10 \
  --min-num-replicas=2 \
  --target-cpu-utilization=0.7 \
  --cool-down-period=120 \
  --scale-in-control-max-scaled-in-replicas=2 \
  --scale-in-control-time-window=300

# Create HTTP health check with proper configuration
gcloud compute health-checks create http $HEALTH_CHECK \
  --port=80 \
  --request-path="/health" \
  --check-interval=10s \
  --timeout=5s \
  --healthy-threshold=2 \
  --unhealthy-threshold=3

# Create backend service with session affinity
gcloud compute backend-services create $BACKEND_SERVICE \
  --protocol=HTTP \
  --health-checks=$HEALTH_CHECK \
  --global \
  --session-affinity=CLIENT_IP \
  --load-balancing-scheme=EXTERNAL

# Add instance group to backend service
gcloud compute backend-services add-backend $BACKEND_SERVICE \
  --instance-group=$INSTANCE_GROUP \
  --instance-group-zone=$ZONE \
  --global \
  --balancing-mode=UTILIZATION \
  --max-utilization=0.8

# Create URL map
gcloud compute url-maps create $URL_MAP \
  --default-service=$BACKEND_SERVICE

# Create HTTP proxy
gcloud compute target-http-proxies create $HTTP_PROXY \
  --url-map=$URL_MAP

# Create global forwarding rule
gcloud compute global-forwarding-rules create $FORWARDING_RULE \
  --target-http-proxy=$HTTP_PROXY \
  --ports=80 \
  --global

# Create firewall rule for load balancer
gcloud compute firewall-rules create allow-http-lb-$TIMESTAMP \
  --allow tcp:80 \
  --target-tags=$VM_TAG \
  --source-ranges=0.0.0.0/0 \
  --description="Allow HTTP traffic for load balancer"

# Create firewall rule for health checks
gcloud compute firewall-rules create allow-health-check-lb-$TIMESTAMP \
  --allow tcp:80 \
  --source-ranges=130.211.0.0/22,35.191.0.0/16 \
  --target-tags=$VM_TAG \
  --description="Allow load balancer health checks"

# Wait for load balancer to be ready
echo "Waiting for load balancer to be ready..."
sleep 60

# Get load balancer IP
LB_IP=$(gcloud compute global-forwarding-rules describe $FORWARDING_RULE --global --format="get(IPAddress)")

echo "Load balancer and autoscaling setup completed successfully!"
echo "Load Balancer IP: $LB_IP"
echo "Access URL: http://$LB_IP"

# Save deployment info for cleanup
cat > test2_deployment.env << EOF
INSTANCE_TEMPLATE=$INSTANCE_TEMPLATE
INSTANCE_GROUP=$INSTANCE_GROUP
HEALTH_CHECK=$HEALTH_CHECK
BACKEND_SERVICE=$BACKEND_SERVICE
URL_MAP=$URL_MAP
HTTP_PROXY=$HTTP_PROXY
FORWARDING_RULE=$FORWARDING_RULE
FIREWALL_RULE_1=allow-http-lb-$TIMESTAMP
FIREWALL_RULE_2=allow-health-check-lb-$TIMESTAMP
EOF
