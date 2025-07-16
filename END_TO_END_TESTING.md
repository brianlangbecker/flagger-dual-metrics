# End-to-End Testing Guide for Honeycomb Adapter

This guide walks through testing the complete Flagger + Honeycomb integration from trace generation to canary deployment decisions.

## Overview

The integration follows this flow:
1. **Instrumented app** sends traces to OTel collector
2. **OTel collector** forwards traces to Honeycomb (using ingest key)
3. **Flagger** queries adapter for metrics
4. **Adapter** creates Honeycomb query, follows Location header, returns COUNT
5. **Flagger** uses metrics for canary analysis decisions

## 1. Prerequisites Setup

### API Keys
You need TWO different Honeycomb API keys:
- **Ingest Key** (`hcaik_*`): For OTel collector to send traces TO Honeycomb
- **Query Key** (`hcqk_*`): For adapter to read metrics FROM Honeycomb

```bash
# Create the query secret (required for adapter)
kubectl create secret generic honeycomb-query-secret \
  --from-literal=api-key="CbUVTd7D7rrdzvcV1FOu8B" \
  -n flagger-system

# Ensure ingest secret exists (for OTel collector)
kubectl get secret honeycomb-otel-secret -n flagger-system
```

### Deploy Components
```bash
# Deploy the instrumented application
kubectl apply -f instrumented-app.yaml

# Deploy the Honeycomb adapter
kubectl apply -f honeycomb-adapter/deployment/adapter-deployment.yaml

# Deploy the metric templates
kubectl apply -f honeycomb-metric-templates.yaml
```

## 2. Verify Component Status

```bash
# Check all pods are running
kubectl get pods -n flagger-system -l app=honeycomb-adapter
kubectl get pods -n test -l app=instrumented-podinfo

# Check adapter logs
kubectl logs -n flagger-system deployment/honeycomb-adapter --tail=20

# Verify adapter is ready
kubectl get pods -n flagger-system -l app=honeycomb-adapter
```

## 3. Generate Test Data

```bash
# Port forward to the instrumented app
kubectl port-forward -n test svc/instrumented-podinfo 8081:8080 &

# Generate some trace data
for i in {1..20}; do
  curl -s localhost:8081/version > /dev/null
  curl -s localhost:8081/delay/0.1 > /dev/null
  curl -s localhost:8081/healthz > /dev/null
done
echo "Generated 60 requests"

# Wait for data to be ingested (usually 30-60 seconds)
sleep 60
```

## 4. Test Adapter Directly

```bash
# Port forward to adapter
kubectl port-forward -n flagger-system svc/honeycomb-adapter 9090:9090 &

# Test the adapter endpoints
curl -s "localhost:9090/api/v1/query" -G -d "query=rate(http_requests_total{service=\"cosmic-canary-service\"}[5m])"

# Expected response (non-zero value indicates success):
# {"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[1752628234,"60.00"]}]}}

# Test different metrics
curl -s "localhost:9090/api/v1/query" -G -d "query=histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{service=\"cosmic-canary-service\"}[5m]))"

# Test health endpoints
curl -s "localhost:9090/-/healthy"  # Should return "OK"
curl -s "localhost:9090/-/ready"    # Should return "Ready"
```

## 5. Test with Flagger

### Create a Canary Resource
```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: cosmic-canary-test
  namespace: test
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: instrumented-podinfo
  service:
    port: 8080
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: success-rate
      templateRef:
        name: honeycomb-success-rate
        namespace: flagger-system
      thresholdRange:
        min: 90
    - name: latency
      templateRef:
        name: honeycomb-latency
        namespace: flagger-system
      thresholdRange:
        max: 500
    - name: request-rate
      templateRef:
        name: honeycomb-request-rate
        namespace: flagger-system
      thresholdRange:
        min: 1
```

### Deploy and Monitor Canary
```bash
# Apply the canary
kubectl apply -f canary-test.yaml

# Watch canary status
kubectl get canary cosmic-canary-test -n test -w

# Check Flagger logs for metric queries
kubectl logs -n flagger-system deployment/flagger --tail=50

# Check canary events
kubectl describe canary cosmic-canary-test -n test
```

## 6. Debug Scripts for Troubleshooting

If something isn't working, use these debug scripts:

```bash
# Check if data exists in Honeycomb (most comprehensive)
./honeycomb-debug-verbose.sh

# Test with polling until query completes
./honeycomb-8h-poll.sh

# Check what datasets exist
./honeycomb-debug-datasets.sh

# Test simple count queries
./honeycomb-simple-count.sh

# Debug service name extraction
./honeycomb-debug-service-name.sh
```

## 7. Expected Results

### Successful Adapter Response
```json
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {},
        "value": [1752628234, "95.00"]
      }
    ]
  }
}
```

### Successful Flagger Analysis
```bash
kubectl get canary cosmic-canary-test -n test -o yaml
```

Should show:
- `status.phase: Progressing` or `Succeeded`
- `status.canaryWeight` increasing over time
- No error messages in conditions

## 8. Success Indicators

- ✅ **Adapter returns non-zero values** (e.g., `"95.00"` instead of `"0.00"`)
- ✅ **Honeycomb UI shows events** in `cosmic-canary-service` dataset
- ✅ **Flagger logs show successful metric queries** without errors
- ✅ **Canary analysis progresses** based on real metrics
- ✅ **Adapter logs show Location header handling** with actual COUNT values

## 9. Common Issues and Solutions

### Issue: Adapter returns 0.00 values
**Cause**: Data not reaching Honeycomb or time window too narrow
**Solution**: 
- Check OTel collector logs: `kubectl logs -n flagger-system deployment/otel-collector`
- Increase time window: `[1h]` instead of `[5m]`
- Verify traces in Honeycomb UI

### Issue: 404 errors from adapter
**Cause**: Wrong API key type (using ingest key instead of query key)
**Solution**: 
- Use query key (`hcqk_*`) not ingest key (`hcaik_*`)
- Verify secret: `kubectl get secret honeycomb-query-secret -n flagger-system -o yaml`

### Issue: Adapter not ready
**Cause**: Missing secret or incorrect key format
**Solution**:
- Check secret exists: `kubectl get secret honeycomb-query-secret -n flagger-system`
- Verify key format in Honeycomb dashboard

### Issue: No traces in Honeycomb
**Cause**: OTel collector not forwarding to Honeycomb
**Solution**:
- Check collector config: `kubectl get configmap otel-collector-config -n flagger-system -o yaml`
- Verify ingest key in `honeycomb-otel-secret`
- Check collector logs for export errors

### Issue: Flagger not using metrics
**Cause**: Metric templates not found or adapter unreachable
**Solution**:
- Verify metric templates: `kubectl get metrictemplate -n flagger-system`
- Check adapter service: `kubectl get svc honeycomb-adapter -n flagger-system`
- Test adapter connectivity from Flagger pod

## 10. Architecture Validation

The complete flow should work as follows:

```
┌─────────────────┐    traces     ┌─────────────────┐    ingest key    ┌─────────────┐
│   Instrumented  │──────────────▶│   OTel          │─────────────────▶│             │
│   Application   │               │   Collector     │   (hcaik_*)      │             │
│                 │               │                 │                  │             │
│ cosmic-canary-  │               │                 │                  │  Honeycomb  │
│ service         │               │                 │                  │             │
└─────────────────┘               └─────────────────┘                  │             │
                                                                       │             │
┌─────────────────┐    PromQL     ┌─────────────────┐    query key     │             │
│    Flagger      │──────────────▶│   Honeycomb     │◀─────────────────│             │
│                 │               │   Adapter       │   (hcqk_*)       │             │
│                 │               │                 │                  └─────────────┘
│ - Canary        │               │ - Two-step      │
│ - Metrics       │               │   query process │
│ - Analysis      │               │ - Location      │
└─────────────────┘               │   header        │
                                  │   handling      │
                                  └─────────────────┘
```

Each component should be working independently and together for successful end-to-end canary deployments with Honeycomb metrics.

## 11. Performance Considerations

- **Query Frequency**: Flagger queries every 30s by default
- **Data Freshness**: Honeycomb ingestion has ~30-60s delay
- **Time Windows**: Use appropriate windows (`[5m]` for real-time, `[1h]` for broader trends)
- **Resource Limits**: Adapter deployment has reasonable CPU/memory limits

## 12. Monitoring and Alerting

Set up monitoring for:
- Adapter pod health and restart count
- Query success/failure rates from adapter logs
- Flagger canary analysis success rates
- Honeycomb API quota usage

This completes the end-to-end testing and validation of the Honeycomb + Flagger integration.