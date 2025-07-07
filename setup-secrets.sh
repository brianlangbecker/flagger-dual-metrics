#!/bin/bash

# Setup script for Flagger with Prometheus metrics (Dynatrace support available but commented out)

echo "Setting up Flagger with Prometheus metrics support..."

# Create namespace if it doesn't exist
kubectl create namespace flagger-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace test --dry-run=client -o yaml | kubectl apply -f -

# Dynatrace configuration (commented out - uncomment when Dynatrace is available)
# echo "Please provide your Dynatrace API token:"
# read -s DYNATRACE_API_TOKEN
# echo "Please provide your Dynatrace environment ID (e.g., abc12345):"
# read DYNATRACE_ENVIRONMENT
# kubectl create secret generic dynatrace-secret \
#   --from-literal=api-token="$DYNATRACE_API_TOKEN" \
#   --namespace=flagger-system

# Optional: Configure Honeycomb for OpenTelemetry Collector
echo ""
echo "Do you want to configure Honeycomb for metrics export? (y/n)"
read -r CONFIGURE_HONEYCOMB

if [ "$CONFIGURE_HONEYCOMB" = "y" ] || [ "$CONFIGURE_HONEYCOMB" = "Y" ]; then
    echo "Please provide your Honeycomb API key:"
    read -s HONEYCOMB_API_KEY
    
    # Create Honeycomb secret for OTel Collector
    kubectl create secret generic honeycomb-otel-secret \
      --from-literal=api-key="$HONEYCOMB_API_KEY" \
      --namespace=flagger-system \
      --dry-run=client -o yaml | kubectl apply -f -
    
    echo "Honeycomb configured! Deploying OpenTelemetry Collector..."
    kubectl apply -f otel-collector-config.yaml
    kubectl apply -f otel-collector-deployment.yaml
else
    echo "Skipping Honeycomb configuration. You can configure it later by running:"
    echo "kubectl create secret generic honeycomb-otel-secret --from-literal=api-key=YOUR_API_KEY --namespace=flagger-system"
    echo "kubectl apply -f otel-collector-config.yaml"
    echo "kubectl apply -f otel-collector-deployment.yaml"
fi

# Apply configurations
# kubectl apply -f dynatrace-secret.yaml  # Uncomment when Dynatrace is available
kubectl apply -f prometheus-config.yaml
kubectl apply -f prometheus-scrape-config.yaml
kubectl apply -f flagger-config.yaml

echo ""
echo "Setup complete! You can now deploy canaries with:"
echo "kubectl apply -f canary-dual-metrics.yaml"
echo ""
echo "To monitor OpenTelemetry Collector (if configured):"
echo "kubectl logs -n flagger-system deployment/otel-collector -f"
echo "kubectl port-forward -n flagger-system svc/otel-collector 55679:55679  # zpages"
echo "Monitor canary deployments with:"
echo "kubectl get canaries -n test"
echo "kubectl describe canary podinfo-canary -n test"