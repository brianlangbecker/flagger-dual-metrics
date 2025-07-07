#!/bin/bash

# Install Flagger on Kubernetes cluster with Istio

set -e

echo "Installing Flagger..."

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

# Check if Helm is available
if ! command -v helm &> /dev/null; then
    echo "Helm is not installed. Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Add Flagger Helm repository
echo "Adding Flagger Helm repository..."
helm repo add flagger https://flagger.app

# Update Helm repositories
echo "Updating Helm repositories..."
helm repo update

# Create flagger-system namespace
echo "Creating flagger-system namespace..."
kubectl create namespace flagger-system --dry-run=client -o yaml | kubectl apply -f -

# Install Flagger with Istio integration
echo "Installing Flagger with Istio integration..."
helm upgrade -i flagger flagger/flagger \
    --namespace=flagger-system \
    --set crd.create=false \
    --set meshProvider=istio \
    --set metricsServer=http://prometheus.istio-system:9090 \
    --set slack.user=flagger \
    --set slack.channel=general

# Install Flagger CRDs
echo "Installing Flagger CRDs..."
kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/main/charts/flagger/crds/crd.yaml

# Install Flagger load testing service
echo "Installing Flagger load testing service..."
kubectl apply -k https://github.com/fluxcd/flagger//kustomize/tester?ref=main

# Wait for Flagger to be ready
echo "Waiting for Flagger to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/flagger -n flagger-system

# Verify installation
echo "Verifying Flagger installation..."
kubectl get pods -n flagger-system

echo "Flagger installation complete!"
echo ""
echo "Flagger is now ready to manage canary deployments!"
echo "You can now run: ./setup-secrets.sh to configure metrics providers"