#!/bin/bash

# Install Istio on local Kubernetes cluster

set -e

echo "Installing Istio..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "Cannot access Kubernetes cluster. Please ensure kubectl is configured."
    exit 1
fi

# Download and install Istio
echo "Downloading Istio..."
curl -L https://istio.io/downloadIstio | sh -

# Find the Istio directory
ISTIO_DIR=$(find . -maxdepth 1 -name "istio-*" -type d | head -1)

if [ -z "$ISTIO_DIR" ]; then
    echo "Failed to find Istio directory"
    exit 1
fi

# Add istioctl to PATH for this session
export PATH=$PWD/$ISTIO_DIR/bin:$PATH

echo "Installing Istio control plane..."
istioctl install --set values.defaultRevision=default -y

# Enable Istio injection for default namespace
echo "Enabling Istio injection for default namespace..."
kubectl label namespace default istio-injection=enabled --overwrite

# Enable Istio injection for test namespace
echo "Creating and enabling Istio injection for test namespace..."
kubectl create namespace test --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace test istio-injection=enabled --overwrite

# Install Istio addons (Prometheus, Grafana, etc.)
echo "Installing Istio addons..."
kubectl apply -f $ISTIO_DIR/samples/addons/prometheus.yaml
kubectl apply -f $ISTIO_DIR/samples/addons/grafana.yaml
kubectl apply -f $ISTIO_DIR/samples/addons/jaeger.yaml
kubectl apply -f $ISTIO_DIR/samples/addons/kiali.yaml

# Wait for deployments to be ready
echo "Waiting for Istio components to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/istiod -n istio-system
kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n istio-system
kubectl wait --for=condition=available --timeout=300s deployment/grafana -n istio-system

echo "Istio installation complete!"
echo ""
echo "To access the Istio dashboards:"
echo "Kiali: kubectl port-forward -n istio-system svc/kiali 20001:20001"
echo "Grafana: kubectl port-forward -n istio-system svc/grafana 3000:3000"
echo "Prometheus: kubectl port-forward -n istio-system svc/prometheus 9090:9090"
echo ""
echo "Istio is now ready for Flagger!"