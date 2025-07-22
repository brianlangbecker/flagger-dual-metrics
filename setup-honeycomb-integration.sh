#!/bin/bash

# Honeycomb Integration Setup Script for Flagger
# This script sets up Honeycomb secrets and deploys components for metrics export and querying
#
# Usage:
#   ./setup-honeycomb-integration.sh                    # Interactive mode
#   ./setup-honeycomb-integration.sh --keep-existing    # Keep existing secrets, auto-deploy
#   ./setup-honeycomb-integration.sh --skip-secrets     # Skip secret setup, deploy only

set -e

# Parse command line arguments
AUTO_KEEP_EXISTING=false
SKIP_SECRETS=false

for arg in "$@"; do
    case $arg in
        --keep-existing)
            AUTO_KEEP_EXISTING=true
            ;;
        --skip-secrets)
            SKIP_SECRETS=true
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --keep-existing    Keep existing secrets and auto-deploy components"
            echo "  --skip-secrets     Skip secret setup, only deploy configurations"
            echo "  --help, -h         Show this help message"
            exit 0
            ;;
    esac
done

echo "🍯 Setting up Honeycomb Integration for Flagger..."
echo "=================================================="

# Function to check if secret exists
check_secret_exists() {
    local secret_name=$1
    local namespace=$2
    kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1
}

# Function to get secret value
get_secret_value() {
    local secret_name=$1
    local namespace=$2
    kubectl get secret "$secret_name" -n "$namespace" -o jsonpath='{.data.api-key}' | base64 -d 2>/dev/null
}

# Function to validate Honeycomb API key format
validate_api_key() {
    local key=$1
    if [[ ${#key} -lt 20 ]]; then
        echo "❌ Invalid API key format (too short). Honeycomb API keys are typically 22+ characters."
        return 1
    fi
    echo "✅ API key format looks valid (${#key} characters)"
    return 0
}

# Create namespaces if they don't exist
echo ""
echo "📁 Creating namespaces..."
kubectl create namespace flagger-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace test --dry-run=client -o yaml | kubectl apply -f -

# Check for existing secrets
echo ""
echo "🔍 Checking for existing Honeycomb secrets..."

INGESTION_SECRET_EXISTS=false
QUERY_SECRET_EXISTS=false

if check_secret_exists "honeycomb-otel-secret" "flagger-system"; then
    INGESTION_SECRET_EXISTS=true
    EXISTING_INGESTION_KEY=$(get_secret_value "honeycomb-otel-secret" "flagger-system")
    echo "✅ Found existing honeycomb-otel-secret (ingestion key: ${EXISTING_INGESTION_KEY:0:8}...)"
else
    echo "❌ honeycomb-otel-secret not found"
fi

if check_secret_exists "honeycomb-query-secret" "flagger-system"; then
    QUERY_SECRET_EXISTS=true
    EXISTING_QUERY_KEY=$(get_secret_value "honeycomb-query-secret" "flagger-system")
    echo "✅ Found existing honeycomb-query-secret (query key: ${EXISTING_QUERY_KEY:0:8}...)"
else
    echo "❌ honeycomb-query-secret not found"
fi

# Setup Honeycomb Ingestion Key (for OTel Collector)
echo ""
echo "🔑 Honeycomb Ingestion Key Setup"
echo "================================="

if [ "$SKIP_SECRETS" = true ]; then
    echo "⏭️  Skipping secret setup (--skip-secrets mode)"
    if [ "$INGESTION_SECRET_EXISTS" = true ]; then
        INGESTION_CHOICE=1
        DEPLOY_OTEL=true
    else
        INGESTION_CHOICE=3
        DEPLOY_OTEL=false
    fi
elif [ "$AUTO_KEEP_EXISTING" = true ] && [ "$INGESTION_SECRET_EXISTS" = true ]; then
    echo "✅ Auto-keeping existing ingestion key (--keep-existing mode)"
    INGESTION_CHOICE=1
elif [ "$INGESTION_SECRET_EXISTS" = true ]; then
    echo "Existing ingestion key found. Do you want to:"
    echo "1) Keep existing key (${EXISTING_INGESTION_KEY:0:8}...)"
    echo "2) Replace with new key"
    echo "3) Skip ingestion key setup"
    read -p "Enter choice (1/2/3): " INGESTION_CHOICE
else
    echo "No existing ingestion key found."
    echo "Do you want to configure Honeycomb ingestion key for metrics export? (y/n)"
    read -p "Choice: " CONFIGURE_INGESTION
    if [ "$CONFIGURE_INGESTION" = "y" ] || [ "$CONFIGURE_INGESTION" = "Y" ]; then
        INGESTION_CHOICE=2
    else
        INGESTION_CHOICE=3
    fi
fi

if [ "$INGESTION_CHOICE" = "2" ]; then
    echo ""
    echo "📝 Please provide your Honeycomb INGESTION key (for sending telemetry data):"
    echo "   - Get this from: Honeycomb → Environment Settings → API Keys"
    echo "   - Permissions needed: 'Send Events' or 'Ingest'"
    read -s -p "Ingestion Key: " HONEYCOMB_INGESTION_KEY
    echo ""
    
    if validate_api_key "$HONEYCOMB_INGESTION_KEY"; then
        kubectl create secret generic honeycomb-otel-secret \
          --from-literal=api-key="$HONEYCOMB_INGESTION_KEY" \
          --namespace=flagger-system \
          --dry-run=client -o yaml | kubectl apply -f -
        echo "✅ Honeycomb ingestion secret created/updated!"
        DEPLOY_OTEL=true
    else
        echo "❌ Skipping ingestion key setup due to invalid key"
        DEPLOY_OTEL=false
    fi
elif [ "$INGESTION_CHOICE" = "1" ]; then
    echo "✅ Keeping existing ingestion key"
    DEPLOY_OTEL=true
else
    echo "⏭️  Skipping ingestion key setup"
    DEPLOY_OTEL=false
fi

# Setup Honeycomb Query Key (for Adapter)
echo ""
echo "🔍 Honeycomb Query Key Setup"
echo "============================="

if [ "$SKIP_SECRETS" = true ]; then
    echo "⏭️  Skipping secret setup (--skip-secrets mode)"
    if [ "$QUERY_SECRET_EXISTS" = true ]; then
        QUERY_CHOICE=1
        DEPLOY_ADAPTER=true
    else
        QUERY_CHOICE=3
        DEPLOY_ADAPTER=false
    fi
elif [ "$AUTO_KEEP_EXISTING" = true ] && [ "$QUERY_SECRET_EXISTS" = true ]; then
    echo "✅ Auto-keeping existing query key (--keep-existing mode)"
    QUERY_CHOICE=1
elif [ "$QUERY_SECRET_EXISTS" = true ]; then
    echo "Existing query key found. Do you want to:"
    echo "1) Keep existing key (${EXISTING_QUERY_KEY:0:8}...)"
    echo "2) Replace with new key" 
    echo "3) Skip query key setup"
    read -p "Enter choice (1/2/3): " QUERY_CHOICE
else
    echo "No existing query key found."
    echo "Do you want to configure Honeycomb query key for direct querying? (y/n)"
    echo "   (This enables Flagger to query Honeycomb directly via the adapter)"
    read -p "Choice: " CONFIGURE_QUERY
    if [ "$CONFIGURE_QUERY" = "y" ] || [ "$CONFIGURE_QUERY" = "Y" ]; then
        QUERY_CHOICE=2
    else
        QUERY_CHOICE=3
    fi
fi

if [ "$QUERY_CHOICE" = "2" ]; then
    echo ""
    echo "📝 Please provide your Honeycomb QUERY key (for reading telemetry data):"
    echo "   - Get this from: Honeycomb → Environment Settings → API Keys"
    echo "   - Permissions needed: 'Read Events' or 'Query'"
    echo "   - ⚠️  This must be DIFFERENT from your ingestion key!"
    read -s -p "Query Key: " HONEYCOMB_QUERY_KEY
    echo ""
    
    if validate_api_key "$HONEYCOMB_QUERY_KEY"; then
        kubectl create secret generic honeycomb-query-secret \
          --from-literal=api-key="$HONEYCOMB_QUERY_KEY" \
          --namespace=flagger-system \
          --dry-run=client -o yaml | kubectl apply -f -
        echo "✅ Honeycomb query secret created/updated!"
        DEPLOY_ADAPTER=true
    else
        echo "❌ Skipping query key setup due to invalid key"
        DEPLOY_ADAPTER=false
    fi
elif [ "$QUERY_CHOICE" = "1" ]; then
    echo "✅ Keeping existing query key"
    DEPLOY_ADAPTER=true
else
    echo "⏭️  Skipping query key setup"
    DEPLOY_ADAPTER=false
fi

# Deploy components based on what was configured
echo ""
echo "🚀 Deploying Honeycomb Integration Components..."
echo "==============================================="

# Deploy OpenTelemetry Collector if ingestion key is configured
if [ "$DEPLOY_OTEL" = true ]; then
    echo "📊 Deploying OpenTelemetry Collector for metrics export..."
    kubectl apply -f otel-collector-config.yaml
    kubectl apply -f otel-collector-deployment.yaml
    echo "✅ OpenTelemetry Collector deployed!"
else
    echo "⏭️  Skipping OpenTelemetry Collector deployment (no ingestion key)"
fi

# Deploy Honeycomb Adapter if query key is configured  
if [ "$DEPLOY_ADAPTER" = true ]; then
    echo "🔄 Deploying Honeycomb-Prometheus Adapter for direct querying..."
    if [ -f "honeycomb-adapter/deployment/adapter-deployment.yaml" ]; then
        kubectl apply -f honeycomb-adapter/deployment/adapter-deployment.yaml
        echo "✅ Honeycomb Adapter deployed!"
    else
        echo "⚠️  Honeycomb adapter deployment files not found. You can deploy manually with:"
        echo "   cd honeycomb-adapter && make build-and-deploy"
    fi
else
    echo "⏭️  Skipping Honeycomb Adapter deployment (no query key)"
fi

# Always deploy basic Prometheus and Flagger configurations
echo ""
echo "⚙️  Deploying base configurations..."
kubectl apply -f prometheus-config.yaml
kubectl apply -f prometheus-scrape-config.yaml  
kubectl apply -f flagger-config.yaml

# Apply Istio telemetry configuration
echo "📡 Applying Istio telemetry configuration..."
kubectl apply -f istio-telemetry-config.yaml

# Summary
echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""

if [ "$DEPLOY_OTEL" = true ]; then
    echo "📊 OpenTelemetry Collector: ✅ DEPLOYED"
    echo "   Purpose: Exports Prometheus metrics to Honeycomb"
    echo "   Monitor: kubectl logs -n flagger-system deployment/otel-collector -f"
    echo "   Health: kubectl port-forward -n flagger-system svc/otel-collector 13133:13133"
fi

if [ "$DEPLOY_ADAPTER" = true ]; then
    echo "🔄 Honeycomb Adapter: ✅ DEPLOYED"
    echo "   Purpose: Enables Flagger to query Honeycomb directly"
    echo "   Monitor: kubectl logs -n flagger-system deployment/honeycomb-adapter -f"
    echo "   Health: kubectl port-forward -n flagger-system svc/honeycomb-adapter 9090:9090"
    echo "   Test: curl http://localhost:9090/-/healthy"
fi

echo ""
echo "🔑 Secrets Status:"
kubectl get secrets -n flagger-system | grep honeycomb || echo "   No Honeycomb secrets found"

echo ""
echo "🚀 Next Steps:"
echo "   1. Deploy a test canary: kubectl apply -f simple-canary.yaml"
echo "   2. Monitor canaries: kubectl get canaries -n test"
echo "   3. Check Flagger logs: kubectl logs -n flagger-system deployment/flagger -f"
echo ""
echo "💡 For direct Honeycomb querying, make sure your MetricTemplates reference the adapter!"