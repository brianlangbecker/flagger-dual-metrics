#!/bin/bash

# Setup script for Flagger with Prometheus and Honeycomb metrics support

echo "Setting up Flagger with Prometheus and Honeycomb metrics support..."

# Create namespace if it doesn't exist
kubectl create namespace flagger-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace test --dry-run=client -o yaml | kubectl apply -f -

# Configure Honeycomb for OpenTelemetry Collector
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
kubectl apply -f prometheus-config.yaml
kubectl apply -f prometheus-scrape-config.yaml
kubectl apply -f flagger-config.yaml

# Apply Istio telemetry configuration to enable HTTP metrics with status codes
echo "Applying Istio telemetry configuration for HTTP metrics..."
kubectl apply -f istio-telemetry-config.yaml

echo ""
echo "Setup complete! You can now deploy canaries with:"
echo "kubectl apply -f simple-canary.yaml  # For testing with working metrics"
echo "kubectl apply -f real-metrics.yaml   # For real Istio metrics"
echo ""
echo "To monitor OpenTelemetry Collector (if configured):"
echo "kubectl logs -n flagger-system deployment/otel-collector -f"
echo "kubectl port-forward -n flagger-system svc/otel-collector 55679:55679  # zpages"
echo ""
echo "Monitor canary deployments with:"
echo "kubectl get canaries -n test"
echo "kubectl describe canary podinfo-canary -n test"