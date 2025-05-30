# =================================================================
# PRACTICAL TEST 5 - Internal-Only VPC Network (IMPROVED)
# =================================================================

#!/bin/bash
# test5_internal_vpc.sh

PROJECT_ID="your-project-id"
TIMESTAMP=$(date +%s)
VPC_NAME="internal-only-vpc-$TIMESTAMP"
SUBNET_NAME="internal-subnet-$TIMESTAMP"
REGION="us-central1"
RANGE="10.0.0.0/16"
VM_NAME="internal-vm-$TIMESTAMP"
ZONE="us-central1-a"
MACHINE_TYPE="e2-medium"
IMAGE_FAMILY="debian-11"
IMAGE_PROJECT="debian-cloud"
TAGS="internal-secure"

echo "Creating internal-only VPC network with enhanced security..."

gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com

# Create custom VPC network
gcloud compute networks create $VPC_NAME \
  --subnet-mode=custom \
  --bgp-routing-mode=regional

echo "Created VPC: $VPC_NAME"

# Create subnet with private Google access and flow logs
gcloud compute networks subnets create $SUBNET_NAME \
  --network=$VPC_NAME \
  --range=$RANGE \
  --region=$REGION \
  --enable-private-ip-google-access \
  --enable-flow-logs \
  --logging-aggregation-interval=INTERVAL_5_SEC \
  --logging-flow-sampling=0.5

echo "Created subnet: $SUBNET_NAME"

# Create comprehensive firewall rules

# 1. Allow internal communication within VPC
gcloud compute firewall-rules create allow-internal-$TIMESTAMP \
  --network=$VPC_NAME \
  --allow tcp,udp,icmp \
  --source-ranges=$RANGE \
  --direction=INGRESS \
  --priority=1000 \
  --target-tags=$TAGS \
  --description="Allow internal VPC communication"

# 2. Allow SSH for management (from specific ranges)
gcloud compute firewall-rules create allow-ssh-internal-$TIMESTAMP \
  --network=$VPC_NAME \
  --allow tcp:22 \
  --source-ranges=$RANGE \
  --direction=INGRESS \
  --priority=1100 \
  --target-tags=$TAGS \
  --description="Allow SSH within VPC"

# 3. Allow Google API access (Private Google Access)
gcloud compute firewall-rules create allow-google-apis-$TIMESTAMP \
  --network=$VPC_NAME \
  --direction=EGRESS \
  --priority=900 \
  --destination-ranges=199.36.153.8/30,199.36.153.4/30 \
  --allow tcp:443 \
  --target-tags=$TAGS \
  --description="Allow Google API access"

# 4. Block all internet egress (highest priority)
gcloud compute firewall-rules create deny-all-egress-$TIMESTAMP \
  --network=$VPC_NAME \
  --direction=EGRESS \
  --priority=65534 \
  --destination-ranges=0.0.0.0/0 \
  --action=deny \
  --target-tags=$TAGS \
  --description="Block all internet egress"

# 5. Explicit deny for common internet services
gcloud compute firewall-rules create deny-internet-ingress-$TIMESTAMP \
  --network=$VPC_NAME \
  --direction=INGRESS \
  --priority=65533 \
  --source-ranges=0.0.0.0/0 \
  --action=deny \
  --target-tags=$TAGS \
  --description="Block internet ingress"

echo "Created firewall rules for network isolation"

# Create VM without external IP
gcloud compute instances create $VM_NAME \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --subnet=$SUBNET_NAME \
  --no-address \
  --tags=$TAGS \
  --image-family=$IMAGE_FAMILY \
  --image-project=$IMAGE_PROJECT \
  --boot-disk-size=20GB \
  --boot-disk-type=pd-standard \
  --metadata=startup-script='#!/bin/bash
# Log startup
echo "INTERNAL VM DEPLOYMENT STARTED at $(date)" > /var/log/internal-setup.log

# Update system using private Google access
apt update >> /var/log/internal-setup.log 2>&1
apt install -y curl wget net-tools >> /var/log/internal-setup.log 2>&1

# Test internal connectivity
echo "=== NETWORK TESTS ===" >> /var/log/internal-setup.log
echo "Hostname: $(hostname)" >> /var/log/internal-setup.log  
echo "Internal IP: $(hostname -I)" >> /var/log/internal-setup.log
echo "Gateway: $(ip route | grep default)" >> /var/log/internal-setup.log

# Test Google API access (should work via Private Google Access)
curl -s -m 10 https://www.googleapis.com/discovery/v1/apis >> /var/log/internal-setup.log 2>&1
if [ $? -eq 0 ]; then
    echo "Google API access: SUCCESS" >> /var/log/internal-setup.log
else
    echo "Google API access: FAILED" >> /var/log/internal-setup.log
fi

# Test internet access (should fail)
curl -s -m 5 http://www.google.com >> /var/log/internal-setup.log 2>&1
if [ $? -eq 0 ]; then
    echo "Internet access: SUCCESS (SECURITY ISSUE!)" >> /var/log/internal-setup.log
else
    echo "Internet access: BLOCKED (Correct)" >> /var/log/internal-setup.log
fi

echo "INTERNAL VM SETUP COMPLETED at $(date)" >> /var/log/internal-setup.log'

echo "Created internal VM: $VM_NAME"

# Wait for VM to start
sleep 30

# Get VM internal IP
INTERNAL_IP=$(gcloud compute instances describe $VM_NAME --zone=$ZONE --format="get(networkInterfaces[0].networkIP)")

echo "Internal-only VPC network setup completed successfully!"
echo "VPC: $VPC_NAME"
echo "Subnet: $SUBNET_NAME ($RANGE)"
echo "VM: $VM_NAME"
echo "Internal IP: $INTERNAL_IP"
echo "Zone: $ZONE"
echo ""
echo "Security Features Implemented:"
echo "- No external IP addresses"
echo "- Private Google Access enabled"
echo "- Flow logs enabled"
echo "- Comprehensive firewall rules"
echo "- Internet access blocked"

# Save deployment info for cleanup
cat > test5_deployment.env << EOF
VPC_NAME=$VPC_NAME
SUBNET_NAME=$SUBNET_NAME
VM_NAME=$VM_NAME
FIREWALL_RULE_1=allow-internal-$TIMESTAMP
FIREWALL_RULE_2=allow-ssh-internal-$TIMESTAMP
FIREWALL_RULE_3=allow-google-apis-$TIMESTAMP
FIREWALL_RULE_4=deny-all-egress-$TIMESTAMP
FIREWALL_RULE_5=deny-internet-ingress-$TIMESTAMP
EOF
