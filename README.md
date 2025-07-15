# Flagger Honeycomb Metrics Setup

This project provides a complete setup for running Flagger with **Honeycomb observability integration**. Flagger validates canary deployments using metrics from Prometheus and forwards telemetry data to Honeycomb for enhanced observability.

## Supported Configurations

✅ **Prometheus Only** (Default - ready to use)
✅ **Prometheus + Honeycomb** (Metrics forwarding to Honeycomb via OpenTelemetry)
✅ **Honeycomb Direct Querying** (Via Honeycomb-Prometheus adapter)

## Overview

Flagger is a progressive delivery tool that automates canary deployments on Kubernetes. This configuration enables Flagger to:

- **Prometheus**: Scrape metrics directly from your applications and Istio service mesh
- **Honeycomb Integration**: Forward metrics to Honeycomb via OpenTelemetry Collector for enhanced observability
- **Direct Honeycomb Querying**: Query Honeycomb directly using the Honeycomb-Prometheus adapter
- **Istio Telemetry**: Collect detailed HTTP metrics with status codes and service identification

**Key Benefit**: Combine Flagger's automated canary validation with Honeycomb's powerful observability platform for comprehensive deployment monitoring.

## How Honeycomb Integration Works

Flagger works with Honeycomb through two approaches:

### Approach 1: Metrics Forwarding (Default)
1. **Prometheus** scrapes metrics from Istio service mesh and applications
2. **OpenTelemetry Collector** reads metrics from Prometheus and forwards to Honeycomb
3. **Flagger** queries Prometheus directly for canary decisions
4. **Honeycomb** receives enriched metrics for analysis and alerting

### Approach 2: Direct Querying (Advanced)
1. **Honeycomb-Prometheus Adapter** translates PromQL queries to Honeycomb API calls
2. **Flagger** queries the adapter as if it were Prometheus
3. **Adapter** executes queries against Honeycomb and returns results in Prometheus format
4. **Canary decisions** are made using live data from Honeycomb

**Key Benefits**:
- Honeycomb receives detailed service telemetry with proper service names
- Flagger can make decisions using either Prometheus or Honeycomb data
- Enhanced observability during canary deployments

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │───►│   Prometheus    │    │    Honeycomb    │
│                 │    │                 │    │                 │
│   (Canary)      │────┼─────────────────┼───►│   (Observability│
└─────────────────┘    └─────────────────┘    │    Platform)    │
                                │              └─────────────────┘
                                │                        ▲
                                ▼                        │
                     ┌─────────────────┐                 │
                     │  OTel Collector │                 │
                     │                 │                 │
                     │  (Scrapes &     │─────────────────┘
                     │   Forwards)     │
                     └─────────────────┘
                                │
                                ▼
               ┌─────────────────────────────────┐
               │             Flagger             │
               │                                 │
               │  → Queries Prometheus           │
               │  → Validates canary metrics     │
               │  → Promotes if metrics pass     │
               │  → Honeycomb stores telemetry   │
               └─────────────────────────────────┘
```

## Provider Definitions

The observability providers are configured in the following locations:

### Prometheus Provider
- **File**: `prometheus-config.yaml` - Basic Prometheus metric templates
- **File**: `real-metrics.yaml` - Real Istio metrics templates
- **Configuration**:
  ```yaml
  provider:
    type: prometheus
    address: http://prometheus.istio-system:9090
  ```

### Honeycomb Integration (OpenTelemetry Collector)
- **File**: `otel-collector-config.yaml` - Honeycomb exporter config with service name extraction
- **File**: `otel-collector-deployment.yaml` - Kubernetes deployment
- **Purpose**: Forwards Prometheus metrics to Honeycomb with proper service identification
- **Key Feature**: Extracts service names from `destination_service_name` labels

### Honeycomb Direct Querying (Advanced)
- **File**: `honeycomb-adapter/` - Honeycomb-Prometheus adapter
- **Purpose**: Enables Flagger to query Honeycomb directly via Prometheus-compatible API
- **Use Case**: Direct canary validation using Honeycomb data

## Files Overview

| File | Purpose |
|------|---------|
| `prometheus-config.yaml` | Prometheus metric templates for Flagger |
| `prometheus-scrape-config.yaml` | Complete Prometheus deployment with scraping configuration |
| `real-metrics.yaml` | Real Istio metrics templates using actual telemetry |
| `canary-honeycomb.yaml` | Example canary deployment with Honeycomb integration |
| `simple-canary.yaml` | Simplified canary deployment with working metrics (recommended for testing) |
| `simple-metrics.yaml` | Simple metric templates using vector queries (guaranteed to work) |
| `flagger-config.yaml` | Main Flagger configuration |
| `otel-collector-config.yaml` | OpenTelemetry Collector configuration with Honeycomb integration |
| `otel-collector-deployment.yaml` | OpenTelemetry Collector deployment and RBAC |
| `honeycomb-otel-secret.yaml` | Honeycomb API credentials for OTel Collector |
| `istio-telemetry-config.yaml` | Istio telemetry configuration for HTTP metrics with status codes |
| `setup-secrets.sh` | Automated setup script |
| `install-istio.sh` | Script to install Istio service mesh |
| `install-flagger.sh` | Script to install Flagger controller |
| `kind-config.yaml` | Configuration for Kind (Kubernetes in Docker) clusters |
| `honeycomb-adapter/` | Honeycomb-Prometheus adapter for direct querying |

## Prerequisites

- Docker Desktop with Kubernetes enabled (allocate at least 4GB RAM and 2 CPUs)
- `kubectl` configured to access your cluster
- Internet access for downloading components
- (Optional) Honeycomb account with API access for metrics forwarding

**Note**: This setup will automatically install Istio and Flagger for you.

## Quick Start

1. **Clone and navigate to the project:**
   ```bash
   git clone <repository-url>
   cd flagger-dual-metrics
   ```

2. **Install Istio (required for traffic management):**
   ```bash
   ./install-istio.sh
   ```

3. **Install Flagger:**
   ```bash
   ./install-flagger.sh
   ```

4. **Configure metrics providers:**
   ```bash
   ./setup-secrets.sh
   ```
   
   This will set up Prometheus metrics and optionally configure Honeycomb via OpenTelemetry Collector.

5. **Deploy the example canary:**
   ```bash
   # For testing/demo purposes (recommended):
   kubectl apply -f simple-canary.yaml
   
   # For production with real Istio metrics:
   kubectl apply -f real-metrics.yaml
   kubectl apply -f canary-honeycomb.yaml
   ```

6. **Monitor the canary deployment:**
   ```bash
   kubectl get canaries -n test
   kubectl describe canary podinfo-canary -n test
   ```

## Optional: Enable Honeycomb Metrics Export

The setup includes an OpenTelemetry Collector that can scrape Prometheus metrics and send them to Honeycomb:

### What it does:
- Scrapes all Prometheus endpoints (Istio, Envoy, application metrics)
- Filters and processes metrics for Honeycomb
- Exports metrics to Honeycomb dataset "flagger-metrics"

### Configuration:
The setup script will prompt you to configure Honeycomb. If you choose yes:
1. Provide your Honeycomb API key
2. The OTel Collector will be deployed automatically

### Manual setup:
```bash
# Create Honeycomb secret
kubectl create secret generic honeycomb-otel-secret \
  --from-literal=api-key=YOUR_HONEYCOMB_API_KEY \
  --namespace=flagger-system

# Deploy OTel Collector
kubectl apply -f otel-collector-config.yaml
kubectl apply -f otel-collector-deployment.yaml

# Monitor the collector
kubectl logs -n flagger-system deployment/otel-collector -f
```

### Accessing OTel Collector diagnostics:
```bash
# zpages for internal metrics
kubectl port-forward -n flagger-system svc/otel-collector 55679:55679
# Open http://localhost:55679

# Health check
kubectl port-forward -n flagger-system svc/otel-collector 13133:13133
# Open http://localhost:13133
```

## Optional: Enable Direct Honeycomb Querying (Advanced)

For advanced users who want Flagger to query Honeycomb directly (instead of just forwarding metrics), you can deploy the Honeycomb-Prometheus adapter:

### What it does:
- Provides a Prometheus-compatible API that Flagger can query
- Translates PromQL queries to Honeycomb Query API calls
- Enables Honeycomb as a direct metrics provider for canary analysis

### Prerequisites:
- Your applications must send telemetry to Honeycomb with these attributes:
  - `service.name` - Service identification
  - `http.status_code` - HTTP status codes
  - `duration_ms` - Request duration
  - `error` - Error tracking (boolean)

### Setup:
```bash
# Navigate to the adapter directory
cd honeycomb-adapter

# Create Honeycomb API secret for the adapter
kubectl create secret generic honeycomb-secret \
  --from-literal=api-key=YOUR_HONEYCOMB_API_KEY \
  --namespace=flagger-system

# Build and deploy the adapter (builds Go code in-cluster)
make build-and-deploy

# Apply Honeycomb-backed metric templates
kubectl apply -f examples/metric-templates.yaml

# Use the Honeycomb canary example
kubectl apply -f examples/canary-example.yaml
```

### Verification:
```bash
# Check adapter health
kubectl port-forward -n flagger-system svc/honeycomb-adapter 9090:9090
curl http://localhost:9090/-/healthy

# Test query translation
curl "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{service=\"test\"}[5m]))"
```

**Note**: This is separate from the OTel Collector setup above. The adapter enables direct querying, while the OTel Collector forwards metrics for storage.

## Detailed Installation Steps

### 1. Install Istio (Required)

**Why Istio?** Flagger requires a service mesh for traffic management during canary deployments. Istio provides:
- Traffic splitting between canary and stable versions
- Automatic sidecar injection for metrics collection
- Advanced routing capabilities
- Built-in Prometheus metrics

The `install-istio.sh` script will:
- Download and install Istio
- Configure the control plane
- Enable Istio injection for default and test namespaces
- Install Istio addons (Prometheus, Grafana, Kiali, Jaeger)

**Verify Istio installation:**
```bash
kubectl get pods -n istio-system
kubectl get svc -n istio-system
```

### 2. Install Flagger

The `install-flagger.sh` script will:
- Install Helm (if not present)
- Add Flagger Helm repository
- Install Flagger with Istio integration
- Install Flagger CRDs and load testing service

**Verify Flagger installation:**
```bash
kubectl get pods -n flagger-system
kubectl logs -n flagger-system deployment/flagger
```

### 3. Configure Metrics Providers

The `setup-secrets.sh` script will prompt you for your Dynatrace credentials and configure both metrics providers.

## Accessing Dashboards

Once everything is installed, you can access various dashboards:

### Kiali (Service Mesh Dashboard)
```bash
kubectl port-forward -n istio-system svc/kiali 20001:20001
# Open http://localhost:20001
```

### Grafana (Metrics Dashboard)
```bash
kubectl port-forward -n istio-system svc/grafana 3000:3000
# Open http://localhost:3000
```

### Prometheus (Metrics Database)
```bash
kubectl port-forward -n istio-system svc/prometheus 9090:9090 &
# Open http://localhost:9090
# Note: The & runs the port-forward in the background
```

**Using the Prometheus UI:**
1. **Check Targets**: Go to Status → Targets to see what endpoints Prometheus is scraping
2. **Query Examples**:
   - View request rate: `sum(rate(envoy_cluster_upstream_rq_total[5m]))`
   - Check success rate: `sum(rate(envoy_cluster_upstream_rq_total{envoy_response_code!~"5.*"}[5m])) / sum(rate(envoy_cluster_upstream_rq_total[5m]))`
   - Monitor latency: `histogram_quantile(0.95, sum(rate(envoy_http_inbound_0_0_0_0_9898_http_downstream_rq_time_bucket[5m])) by (le))`
   - Alternative: Use Istio metrics if available: `sum(rate(istio_requests_total[5m]))`
3. **Graph Tab**: Visualize metrics over time
4. **Alerts Tab**: View any configured alerts

**Troubleshooting No Data:**
1. **Check if targets are UP**: Status → Targets - all should show "UP" status
2. **Verify namespace injection**: `kubectl get namespace -L istio-injection` 
3. **Deploy test app first**: Deploy the canary example to generate metrics
4. **Generate traffic**: Port-forward to your app and send requests: `curl http://localhost:9898/`
5. **Check basic metrics**: Try simpler queries first like `up` or `prometheus_build_info`
6. **Verify Istio sidecars**: `kubectl get pods -o wide` - should see 2/2 containers
7. **If istio_requests_total is empty**: Try Envoy metrics instead (see query examples above)
8. **Check available metrics**: Use `{__name__=~".*request.*"}` to see what request metrics exist

## Testing the Setup

### 1. Check Canary Status
```bash
kubectl get canaries -n test
kubectl describe canary podinfo-canary -n test
```

### 2. Generate Traffic
```bash
# Port forward to the application
kubectl port-forward -n test svc/podinfo 9898:9898

# Generate some traffic
curl http://localhost:9898/
```

### 3. Trigger a Canary Deployment

**Method 1: Update Container Image**
```bash
# Update the image to trigger a canary
kubectl set image deployment/podinfo -n test podinfod=ghcr.io/stefanprodan/podinfo:6.0.1
```

**Method 2: Update Environment Variables**
```bash
# Change an environment variable
kubectl patch deployment podinfo -n test -p='{"spec":{"template":{"spec":{"containers":[{"name":"podinfod","env":[{"name":"PODINFO_UI_COLOR","value":"#green"}]}]}}}}'
```

**Method 3: Edit Deployment Directly**
```bash
# Edit the deployment YAML
kubectl edit deployment podinfo -n test
# Change any spec.template field (image, env vars, resources, etc.)
```

**Method 4: Apply Updated YAML**
```bash
# Modify canary-dual-metrics.yaml and reapply
# Change the image tag or any container spec
kubectl apply -f canary-dual-metrics.yaml
```

**What Triggers a Canary:**
- Any change to `spec.template` in the deployment
- Image tag updates
- Environment variable changes  
- Resource limit modifications
- Volume mount changes

### 4. Monitor the Canary

**Real-time Monitoring:**
```bash
# Watch the canary progress in real-time
kubectl get canary podinfo-canary -n test -w

# Check Flagger events
kubectl get events -n test --sort-by=.metadata.creationTimestamp

# Monitor Flagger controller logs
kubectl logs -n flagger-system deployment/flagger -f
```

**Check Canary Status:**
```bash
# Get detailed canary status
kubectl describe canary podinfo-canary -n test

# Check current traffic weights
kubectl get canary podinfo-canary -n test -o jsonpath='{.status}'

# Monitor pod rollout
kubectl get pods -n test -w
```

**Expected Canary Progression:**
1. **Initialized** → Canary deployment created, 0% traffic
2. **Progressing** → Traffic gradually increases (5% → 10% → 15%...)
3. **Promoting** → All checks passed, promoting to 100%
4. **Succeeded** → Canary becomes primary, old pods terminated

**Or if issues occur:**
1. **Failed** → Metrics failed thresholds, rolling back
2. **Terminated** → Manual intervention or critical failure

## Understanding Canary Metrics in Prometheus

During a canary deployment, Flagger will analyze these key metrics:

### What You Should See:

**1. Traffic Split Metrics:**
- `envoy_cluster_upstream_rq_total{envoy_cluster_name="outbound|9898||podinfo-primary.test.svc.cluster.local"}` - Primary traffic
- `envoy_cluster_upstream_rq_total{envoy_cluster_name="outbound|9898||podinfo-canary.test.svc.cluster.local"}` - Canary traffic

**2. Success Rate Metrics:**
- Monitor response codes: `envoy_cluster_upstream_rq_total{envoy_response_code="200"}` vs `envoy_response_code="500"`
- Flagger checks: Success rate must be ≥ 95% (configurable in canary spec)

**3. Latency Metrics:**
- Check available latency metrics with: `{__name__=~".*time.*"}` or `{__name__=~".*duration.*"}`
- Flagger checks: P95 latency must be ≤ 500ms (configurable)

**4. Request Rate:**
- `envoy_cluster_upstream_rq_total` - Total requests per second
- Flagger checks: Must have minimum traffic (≥ 1 req/s by default)

### Canary Deployment Phases:

**Phase 1 - Initialization (Weight: 0%)**
- All traffic goes to primary: `podinfo-primary`
- Canary pod starts but receives no traffic

**Phase 2 - Analysis (Weight: 5%, 10%, 15%...)**
- Traffic gradually shifts to canary
- Flagger queries Prometheus every 1 minute
- Must pass all metric thresholds for 5 consecutive checks

**Phase 3 - Promotion or Rollback**
- **Success**: Canary becomes primary (Weight: 100%)
- **Failure**: Traffic returns to primary (Weight: 0%), canary pods terminated

### Key Prometheus Queries During Canary:

```promql
# Traffic distribution
sum(rate(envoy_cluster_upstream_rq_total[1m])) by (envoy_cluster_name)

# Success rate by service
sum(rate(envoy_cluster_upstream_rq_total{envoy_response_code!~"5.*"}[1m])) by (envoy_cluster_name) / 
sum(rate(envoy_cluster_upstream_rq_total[1m])) by (envoy_cluster_name)

# Latency comparison (use available latency metrics in your environment)
# Check what latency metrics are available with: {__name__=~".*time.*"} or {__name__=~".*duration.*"}
```

### Flagger Decision Logic:
- **Promote**: All metrics pass thresholds for consecutive checks
- **Hold**: Some metrics fail, retry analysis  
- **Rollback**: Metrics fail repeatedly or critical failure detected

## Metrics Configuration

### Prometheus Metrics

The Prometheus configuration includes three key metrics:

- **Success Rate**: Percentage of successful HTTP requests (non-5xx responses)
- **Latency**: 95th percentile response time
- **Request Rate**: Number of requests per second

### Honeycomb Metrics (Optional)

When using the Honeycomb adapter, the configuration includes:

- **Success Rate**: HTTP success rate from Honeycomb telemetry data
- **Latency**: P95 response time from Honeycomb telemetry data

**Note**: Honeycomb metrics are available via the Honeycomb-Prometheus adapter. See the "Optional: Enable Direct Honeycomb Querying" section.

## Canary Analysis Process

1. **Traffic Split**: Flagger gradually shifts traffic from stable to canary version
2. **Metric Collection**: Prometheus metrics are collected and optionally forwarded to Honeycomb
3. **Threshold Validation**: All metrics must pass their thresholds
4. **Decision Making**: If any metric fails, the canary is rolled back
5. **Promotion**: If all metrics pass, the canary becomes the new stable version

## Customization

### Adjusting Thresholds

Edit the `thresholdRange` values in `canary-honeycomb.yaml`:

```yaml
thresholdRange:
  min: 95  # Success rate must be >= 95%
  max: 500 # Latency must be <= 500ms
```

### Adding Custom Metrics

1. Create a new metric template in the appropriate config file
2. Reference it in your canary configuration
3. Apply the changes to your cluster

### Modifying Analysis Settings

Adjust the canary analysis behavior:

```yaml
analysis:
  interval: 1m        # How often to run analysis
  threshold: 5        # Number of failed checks before rollback
  maxWeight: 50       # Maximum traffic percentage for canary
  stepWeight: 5       # Traffic increment per successful check
```

## Monitoring and Troubleshooting

### Check Canary Status
```bash
kubectl get canaries -A
kubectl describe canary <canary-name> -n <namespace>
```

### View Flagger Logs
```bash
kubectl logs -n flagger-system deployment/flagger -f
```

### Common Issues

1. **Pods not starting**: Check resource limits
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```

2. **Istio injection not working**: Verify namespace labeling
   ```bash
   kubectl get namespace -L istio-injection
   ```

3. **Metrics not available**: Check Prometheus targets
   ```bash
   kubectl port-forward -n istio-system svc/prometheus 9090:9090
   # Open http://localhost:9090/targets
   ```

4. **Flagger not promoting canary**: Check Flagger logs
   ```bash
   kubectl logs -n flagger-system deployment/flagger -f
   ```

5. **Metric template parsing errors**: Use simple metrics for testing
   ```bash
   # If you see "function args not defined" or JSON parsing errors:
   kubectl apply -f simple-metrics.yaml
   kubectl apply -f simple-canary.yaml
   
   # These use static vector queries that always pass
   ```

### Resource Requirements

Minimum recommended resources for local testing:
- **CPU**: 4 cores
- **Memory**: 8GB RAM
- **Storage**: 20GB available

### Network Configuration

Ensure your local cluster can access:
- Docker Hub (for container images)
- Istio release repositories
- Flagger Helm repository
- Dynatrace API endpoints

## Security Considerations

- Store API tokens securely using Kubernetes secrets
- Use RBAC to limit access to Flagger resources
- Regularly rotate API credentials
- Monitor access logs for anomalies

## Advanced Configuration

### Custom Istio Installation
If you need specific Istio features, modify the installation:

```bash
# Custom Istio installation
istioctl install --set values.pilot.env.EXTERNAL_ISTIOD=true
```

### Custom Prometheus Queries

Modify the queries in `prometheus-config.yaml` to match your application's metrics:

```yaml
query: |
  sum(rate(http_requests_total{job="my-app",code!~"5.."}[5m])) / 
  sum(rate(http_requests_total{job="my-app"}[5m])) * 100
```

### Dynatrace Custom Metrics

Update the Dynatrace queries to use your specific service entities:

```yaml
query: |
  builtin:service.response.time:splitBy("dt.entity.service"):filter(eq("dt.entity.service","SERVICE-123456"))
```

### Production Considerations
For production use:
- Use proper TLS certificates
- Configure resource limits and requests
- Set up proper RBAC
- Use persistent storage for metrics
- Configure alerting and monitoring

## Next Steps

1. **Explore the Kiali dashboard** to visualize your service mesh
2. **Set up custom applications** for canary deployments
3. **Configure alerts** for failed canary deployments
4. **Integrate with CI/CD** pipelines for automated deployments

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review logs from Istio and Flagger components
3. Consult the official documentation:
   - [Istio Documentation](https://istio.io/latest/docs/)
   - [Flagger Documentation](https://docs.flagger.app/)
   - [Dynatrace API Documentation](https://www.dynatrace.com/support/help/dynatrace-api/)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.