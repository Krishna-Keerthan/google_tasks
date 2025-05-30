# =================================================================
# CLEANUP SCRIPT FOR TEST 1 - Single VM (IMPROVED)
# =================================================================

#!/bin/bash
# cleanup_test1.sh

PROJECT_ID="your-project-id"
ZONE="us-central1-a"

echo "Cleaning up Test 1 resources..."
gcloud config set project $PROJECT_ID

# Load deployment environment variables if available
if [ -f "test1_deployment.env" ]; then
    source test1_deployment.env
    echo "Found deployment configuration"
else
    echo "Warning: No deployment configuration found, using default names"
    VM_NAME="web-server"
    FIREWALL_RULE_1="allow-web-traffic"
    FIREWALL_RULE_2="allow-health-check"
fi

# Delete VM instances
echo "Deleting VM instances..."
if [ ! -z "$VM_NAME" ]; then
    gcloud compute instances delete $VM_NAME --zone=$ZONE --quiet 2>/dev/null
    echo "Deleted VM: $VM_NAME"
else
    # Cleanup any web-server VMs
    for vm in $(gcloud compute instances list --filter="name~'^web-server'" --format="value(name,zone)" | grep $ZONE | cut -f1); do
        gcloud compute instances delete $vm --zone=$ZONE --quiet 2>/dev/null
        echo "Deleted VM: $vm"
    done
fi

# Delete firewall rules
echo "Deleting firewall rules..."
if [ ! -z "$FIREWALL_RULE_1" ]; then
    gcloud compute firewall-rules delete $FIREWALL_RULE_1 --quiet 2>/dev/null
    echo "Deleted firewall rule: $FIREWALL_RULE_1"
fi

if [ ! -z "$FIREWALL_RULE_2" ]; then
    gcloud compute firewall-rules delete $FIREWALL_RULE_2 --quiet 2>/dev/null
    echo "Deleted firewall rule: $FIREWALL_RULE_2"
fi

# Cleanup any remaining web traffic firewall rules
for rule in $(gcloud compute firewall-rules list --filter="name~'allow-web-traffic'" --format="value(name)"); do
    gcloud compute firewall-rules delete $rule --quiet 2>/dev/null
    echo "Deleted firewall rule: $rule"
done

# Delete persistent disks if any
echo "Checking for orphaned disks..."
for disk in $(gcloud compute disks list --filter="name~'^web-server'" --zones=$ZONE --format="value(name)"); do
    gcloud compute disks delete $disk --zone=$ZONE --quiet 2>/dev/null
    echo "Deleted disk: $disk"
done

# Remove deployment configuration
rm -f test1_deployment.env

echo "Test 1 cleanup completed!"
