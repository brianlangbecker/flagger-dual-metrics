# Approach 2: Direct Honeycomb Querying - Quick Start Guide

## Overview
This guide walks you through setting up **Approach 2** where Flagger queries Honeycomb directly via the Honeycomb-Prometheus adapter, rather than using Prometheus as an intermediary.

## Prerequisites
- Kubernetes cluster running (Docker Desktop, Kind, etc.)
- Istio and Flagger already installed
- Honeycomb account with API keys

## Step-by-Step Instructions

### Step 1: Deploy the Honeycomb Adapter
```bash
# Navigate to the honeycomb adapter directory
cd honeycomb-adapter

# Build and deploy the adapter
docker build -t honeycomb-adapter:latest .
kubectl apply -f honeycomb-deployment.yaml

# Wait for deployment to be ready
kubectl wait --for=condition=available --timeout=60s deployment/honeycomb-adapter -n flagger-system
```

### Step 2: Apply Honeycomb-Backed Metric Templates
```bash
# Deploy the generic metric templates (100% service-agnostic)
kubectl apply -f examples/metric-templates.yaml

# Verify templates are created
kubectl get metrictemplates -n flagger-system
```

### Step 3: Deploy Test Service with OpenTelemetry
```bash
# Deploy the cosmic-canary test service
kubectl apply -f simple-otel-app-deployment.yaml

# Wait for deployment to be ready
kubectl wait --for=condition=available --timeout=120s deployment/cosmic-canary-service -n test
```

### Step 4: Start Parallel Traffic Generators (CRITICAL)
```bash
# Deploy multiple traffic generators for continuous telemetry flow
kubectl run traffic-health --image=busybox --restart=Never -- /bin/sh -c 'while true; do wget -q -O- http://cosmic-canary-service.test:8000/health; sleep 1; done'

kubectl run traffic-main --image=busybox --restart=Never -- /bin/sh -c 'while true; do wget -q -O- http://cosmic-canary-service.test:8000/; sleep 2; done'

kubectl run traffic-version --image=busybox --restart=Never -- /bin/sh -c 'while true; do wget -q -O- http://cosmic-canary-service.test:8000/version; sleep 3; done'

# Verify traffic is flowing
kubectl logs traffic-health --tail=3
kubectl logs traffic-main --tail=3
```

### Step 5: Wait for Telemetry Data in Honeycomb
```bash
# Allow 3-5 minutes for telemetry to flow to Honeycomb
echo "⏳ Waiting for telemetry data to appear in Honeycomb..."
sleep 180

# Check Honeycomb UI: 
# - Go to your Honeycomb account
# - Look for dataset: cosmic-canary-service
# - Verify data is flowing with service.name = "cosmic-canary-service"
```

### Step 6: Deploy Canary Configuration
```bash
# Deploy the canary that uses Honeycomb metrics
kubectl apply -f cosmic-canary-honeycomb.yaml

# Wait for canary to initialize
sleep 60
kubectl get canary cosmic-canary -n test
```

### Step 7: Trigger Canary Deployment
```bash
# Trigger a deployment change to start canary analysis
kubectl patch deployment cosmic-canary-service -n test -p '{"spec":{"template":{"metadata":{"annotations":{"test-run":"approach2-demo"}}}}}'

# Monitor canary progression
kubectl get canary cosmic-canary -n test -w
```

### Step 8: Monitor and Verify
```bash
# Check canary status (should progress: Initializing → Initialized → Progressing → Succeeded)
kubectl get canary cosmic-canary -n test

# Check adapter logs for Honeycomb queries
kubectl logs -n flagger-system -l app=honeycomb-adapter --tail=20

# Check Flagger controller logs
kubectl logs -n flagger-system -l app.kubernetes.io/name=flagger --tail=10
```

## Expected Results

### Successful Canary Progression:
```
NAME            STATUS        WEIGHT   LASTTRANSITIONTIME
cosmic-canary   Initialized   0        [timestamp]
cosmic-canary   Progressing   0        [timestamp]
cosmic-canary   Progressing   10       [timestamp]
cosmic-canary   Progressing   20       [timestamp]
cosmic-canary   Succeeded     0        [timestamp]
```

### Adapter Logs Should Show:
```
🔍 Received PromQL query: sum(rate(http_requests_total{service="cosmic-canary-service"}[180s]))
📍 Found service name: cosmic-canary-service
📊 Query execution results: COUNT:590
✅ Extracted value 590.000000 from field COUNT
📊 Returning Prometheus response
```

## Verification Commands

### Health Checks:
```bash
# Test adapter health
kubectl port-forward -n flagger-system svc/honeycomb-adapter 9090:9090 &
curl http://localhost:9090/-/healthy
curl http://localhost:9090/-/ready
```

### Traffic Verification:
```bash
# Check traffic generators are running
kubectl get pods | grep traffic

# Verify service is responding
kubectl logs traffic-health --tail=5
```

### Honeycomb Data Verification:
```bash
# Check service logs for telemetry
kubectl logs -n test -l app=cosmic-canary-service --tail=10

# Port forward to test service directly
kubectl port-forward -n test svc/cosmic-canary-service 8080:8000 &
curl http://localhost:8080/health
```

## Troubleshooting

### Common Issues:

**1. Canary Stuck at "Initializing"**
```bash
# Check Flagger logs
kubectl logs -n flagger-system -l app.kubernetes.io/name=flagger --tail=20

# Common causes: VirtualService issues, primary deployment not ready
```

**2. Adapter Returning No Data**
```bash
# Check if data exists in Honeycomb for the service
# Verify service.name = "cosmic-canary-service" in Honeycomb UI

# Check adapter logs for Honeycomb API errors
kubectl logs -n flagger-system -l app=honeycomb-adapter --tail=30
```

**3. Traffic Generators Not Working**
```bash
# Check traffic generator pod status
kubectl describe pod traffic-health

# Restart traffic generators if needed
kubectl delete pod traffic-health traffic-main traffic-version
# Then re-run Step 4
```

**4. Metrics Query Failures**
```bash
# Test adapter directly
kubectl port-forward -n flagger-system svc/honeycomb-adapter 9090:9090 &
curl "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{service=\"cosmic-canary-service\"}[180s]))"
```

## Key Success Factors

### ✅ Critical Requirements:
1. **Parallel traffic generators** must be running throughout canary deployment
2. **3+ minutes of telemetry data** in Honeycomb before starting canary
3. **Honeycomb query API key** (not ingestion key) must be configured
4. **service.name** attribute must be present in telemetry data

### ✅ Generic Implementation:
- **Zero hardcoded service names** - templates use `{{ target }}` variables
- **Works with any service** - just change the deployment name in canary config
- **Production scalable** - one template set for unlimited services

## Cleanup (Optional)
```bash
# Stop traffic generators
kubectl delete pod traffic-health traffic-main traffic-version

# Remove test canary and service
kubectl delete canary cosmic-canary -n test
kubectl delete -f simple-otel-app-deployment.yaml

# Remove adapter (if desired)
kubectl delete deployment honeycomb-adapter -n flagger-system
kubectl delete -f examples/metric-templates.yaml
```

## Next Steps
- Deploy your own services with OpenTelemetry instrumentation
- Create canary configurations for your services using the same template pattern
- Monitor deployments in both Honeycomb and Flagger dashboards