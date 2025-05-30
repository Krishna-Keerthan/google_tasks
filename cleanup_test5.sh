# =================================================================
# CLEANUP SCRIPT FOR TEST 5 - Internal VPC Network (IMPROVED)
# =================================================================

#!/bin/bash
# cleanup_test5.sh

PROJECT_ID="your-project-id"
ZONE="us-central1-a"
REGION="us-central1"

echo "Cleaning up Test 5 resources..."
gcloud config set project $PROJECT_ID

# Load deployment environment variables if available
if [ -f "test5_deployment.env" ]; then
    source test5_deployment.env
    echo "Found deployment configuration"
else
    echo "Warning: No deployment configuration found, using pattern matching"
fi

# Delete VMs first
echo "Deleting VM instances..."
if [ ! -z "$VM_NAME" ]; then
    gcloud compute instances delete $VM_NAME --zone=$ZONE --quiet 2>/dev/null
    echo "Deleted VM: $VM_NAME"
else
    for vm in $(gcloud compute instances list --filter="name~'internal-vm'" --format="value(name,zone)" | grep $ZONE | cut -f1); do
        gcloud compute instances delete $vm --zone=$ZONE --quiet 2>/dev/null
        echo "Deleted VM: $vm"
    done
fi

# Delete firewall rules
echo "Deleting firewall rules..."
for i in {1..5}; do
    firewall_var="FIREWALL_RULE_$i"
    firewall_rule=${!firewall_var}
    if [ ! -z "$firewall_rule" ]; then
        gcloud compute firewall-rules delete $firewall_rule --quiet 2>/dev/null
        echo "Deleted firewall rule: $firewall_rule"
    fi
done

# Cleanup any remaining internal firewall rules
for rule in $(gcloud compute firewall-rules list --filter="name~'allow-internal'" --format="value(name)"); do
    gcloud compute firewall-rules delete $rule --quiet 2>/dev/null
    echo "Deleted firewall rule: $rule"
done

for rule in $(gcloud compute firewall-rules list --filter="name~'deny-all-egress'" --format="value(name)"); do
    gcloud compute firewall-rules delete $rule --quiet 2>/dev/null
    echo "Deleted firewall rule: $rule"
done

for rule in $(gcloud compute firewall-rules list --filter="name~'deny-internet-ingress'" --format="value(name)"); do
    gcloud compute firewall-rules delete $rule --quiet 2>/dev/null
    echo "Deleted firewall rule: $rule"
done

for rule in $(gcloud compute firewall-rules list --filter="name~'allow-ssh-internal'" --format="value(name)"); do
    gcloud compute firewall-rules delete $rule --quiet 2>/dev/null
    echo "Deleted firewall rule: $rule"
done

for rule in $(gcloud compute firewall-rules list --filter="name~'allow-google-apis'" --format="value(name)"); do
    gcloud compute firewall-rules delete $rule --quiet 2>/dev/null
    echo "Deleted firewall rule: $rule"
done

# Delete subnets
echo "Deleting subnets..."
if [ ! -z "$SUBNET_NAME" ]; then
    gcloud compute networks subnets delete $SUBNET_NAME --region=$REGION --quiet 2>/dev/null
    echo "Deleted subnet: $SUBNET_NAME"
else
    for subnet in $(gcloud compute networks subnets list --filter="name~'internal-subnet'" --format="value(name,region)" | grep $REGION | cut -f1); do
        gcloud compute networks subnets delete $subnet --region=$REGION --quiet 2>/dev/null
        echo "Deleted subnet: $subnet"
    done
fi

# Delete VPC networks
echo "Deleting VPC networks..."
if [ ! -z "$VPC_NAME" ]; then
    gcloud compute networks delete $VPC_NAME --quiet 2>/dev/null
    echo "Deleted VPC: $VPC_NAME"
else
    for vpc in $(gcloud compute networks list --filter="name~'internal-only-vpc'" --format="value(name)"); do
        gcloud compute networks delete $vpc --quiet 2>/dev/null
        echo "Deleted VPC: $vpc"
    done
fi

# Delete any orphaned disks
echo "Checking for orphaned disks..."
for disk in $(gcloud compute disks list --filter="name~'internal-vm'" --zones=$ZONE --format="value(name)"); do
    gcloud compute disks delete $disk --zone=$ZONE --quiet 2>/dev/null
    echo "Deleted disk: $disk"
done

# Remove deployment configuration
rm -f test5_deployment.env

echo "Test 5 cleanup completed!"
