# =================================================================
# CLEANUP SCRIPT FOR TEST 2 - Load Balancer (IMPROVED)
# =================================================================

#!/bin/bash
# cleanup_test2.sh

PROJECT_ID="your-project-id"
ZONE="us-central1-a"

echo "Cleaning up Test 2 resources..."
gcloud config set project $PROJECT_ID

# Load deployment environment variables if available
if [ -f "test2_deployment.env" ]; then
    source test2_deployment.env
    echo "Found deployment configuration"
else
    echo "Warning: No deployment configuration found, using pattern matching"
fi

# Delete in reverse order of creation

# Delete global forwarding rules
echo "Deleting global forwarding rules..."
if [ ! -z "$FORWARDING_RULE" ]; then
    gcloud compute global-forwarding-rules delete $FORWARDING_RULE --quiet 2>/dev/null
    echo "Deleted forwarding rule: $FORWARDING_RULE"
else
    for rule in $(gcloud compute global-forwarding-rules list --filter="name~'web-forwarding-rule'" --format="value(name)"); do
        gcloud compute global-forwarding-rules delete $rule --quiet 2>/dev/null
        echo "Deleted forwarding rule: $rule"
    done
fi

# Delete target HTTP proxies
echo "Deleting target HTTP proxies..."
if [ ! -z "$HTTP_PROXY" ]; then
    gcloud compute target-http-proxies delete $HTTP_PROXY --quiet 2>/dev/null
    echo "Deleted HTTP proxy: $HTTP_PROXY"
else
    for proxy in $(gcloud compute target-http-proxies list --filter="name~'web-http-proxy'" --format="value(name)"); do
        gcloud compute target-http-proxies delete $proxy --quiet 2>/dev/null
        echo "Deleted HTTP proxy: $proxy"
    done
fi

# Delete URL maps
echo "Deleting URL maps..."
if [ ! -z "$URL_MAP" ]; then
    gcloud compute url-maps delete $URL_MAP --quiet 2>/dev/null
    echo "Deleted URL map: $URL_MAP"
else
    for urlmap in $(gcloud compute url-maps list --filter="name~'web-url-map'" --format="value(name)"); do
        gcloud compute url-maps delete $urlmap --quiet 2>/dev/null
        echo "Deleted URL map: $urlmap"
    done
fi

# Delete backend services
echo "Deleting backend services..."
if [ ! -z "$BACKEND_SERVICE" ]; then
    gcloud compute backend-services delete $BACKEND_SERVICE --global --quiet 2>/dev/null
    echo "Deleted backend service: $BACKEND_SERVICE"
else
    for service in $(gcloud compute backend-services list --global --filter="name~'web-backend-service'" --format="value(name)"); do
        gcloud compute backend-services delete $service --global --quiet 2>/dev/null
        echo "Deleted backend service: $service"
    done
fi

# Delete health checks
echo "Deleting health checks..."
if [ ! -z "$HEALTH_CHECK" ]; then
    gcloud compute health-checks delete $HEALTH_CHECK --quiet 2>/dev/null
    echo "Deleted health check: $HEALTH_CHECK"
else
    for hc in $(gcloud compute health-checks list --filter="name~'web-health-check'" --format="value(name)"); do
        gcloud compute health-checks delete $hc --quiet 2>/dev/null
        echo "Deleted health check: $hc"
    done
fi

# Delete managed instance groups
echo "Deleting managed instance groups..."
if [ ! -z "$INSTANCE_GROUP" ]; then
    # First, resize to 0 to gracefully shut down instances
    gcloud compute instance-groups managed resize $INSTANCE_GROUP --size=0 --zone=$ZONE --quiet 2>/dev/null
    sleep 30
    gcloud compute instance-groups managed delete $INSTANCE_GROUP --zone=$ZONE --quiet 2>/dev/null
    echo "Deleted instance group: $INSTANCE_GROUP"
else
    for ig in $(gcloud compute instance-groups managed list --filter="name~'web-instance-group'" --zones=$ZONE --format="value(name)"); do
        gcloud compute instance-groups managed resize $ig --size=0 --zone=$ZONE --quiet 2>/dev/null
        sleep 30
        gcloud compute instance-groups managed delete $ig --zone=$ZONE --quiet 2>/dev/null
        echo "Deleted instance group: $ig"
    done
fi

# Delete instance templates
echo "Deleting instance templates..."
if [ ! -z "$INSTANCE_TEMPLATE" ]; then
    gcloud compute instance-templates delete $INSTANCE_TEMPLATE --quiet 2>/dev/null
    echo "Deleted instance template: $INSTANCE_TEMPLATE"
else
    for template in $(gcloud compute instance-templates list --filter="name~'web-instance-template'" --format="value(name)"); do
        gcloud compute instance-templates delete $template --quiet 2>/dev/null
        echo "Deleted instance template: $template"
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

# Cleanup any remaining load balancer firewall rules
for rule in $(gcloud compute firewall-rules list --filter="name~'allow-http-lb'" --format="value(name)"); do
    gcloud compute firewall-rules delete $rule --quiet 2>/dev/null
    echo "Deleted firewall rule: $rule"
done

for rule in $(gcloud compute firewall-rules list --filter="name~'allow-health-check-lb'" --format="value(name)"); do
    gcloud compute firewall-rules delete $rule --quiet 2>/dev/null
    echo "Deleted firewall rule: $rule"
done

# Remove deployment configuration
rm -f test2_deployment.env

echo "Test 2 cleanup completed!"
