# Flagger Multi-Provider Metrics Setup

This project provides a complete setup for running Flagger with **multiple observability providers simultaneously**. Flagger can validate canary deployments using metrics from different sources concurrently for enhanced reliability.

## Supported Configurations

✅ **Prometheus Only** (Default - ready to use)
✅ **Prometheus + Dynatrace** (Dual validation - Dynatrace commented out by default)  
✅ **Prometheus + Honeycomb** (via OpenTelemetry Collector)
✅ **All Three Providers** (Triple validation when all are configured)

## Overview

Flagger is a progressive delivery tool that automates canary deployments on Kubernetes. This configuration enables Flagger to:

- **Prometheus**: Scrape metrics directly from your applications and Istio service mesh
- **Dynatrace**: Query advanced observability metrics from Dynatrace's APM platform (configured but commented out)
- **Honeycomb**: Receive metrics via OpenTelemetry Collector for centralized observability
- **Multi-Provider Validation**: Use multiple metric sources simultaneously to ensure canary deployments are safe and reliable

**Key Benefit**: If one metrics provider has issues, Flagger can still make decisions using the other providers, increasing deployment reliability.

## How Multi-Provider Validation Works

Flagger doesn't directly connect to multiple observability platforms. Instead, it works through **MetricTemplate** resources:

1. **MetricTemplates** define queries for specific providers (Prometheus, Dynatrace, Honeycomb)
2. **Canary resources** reference multiple MetricTemplates from different providers
3. **Flagger evaluates ALL metrics** from all referenced templates during each analysis interval
4. **Promotion only happens** when ALL metrics from ALL providers pass their thresholds
5. **If ANY metric fails** (from any provider), the canary is held or rolled back

**Example**: A canary might use:
- Prometheus MetricTemplate for success rate
- Dynatrace MetricTemplate for latency  
- Honeycomb MetricTemplate for request rate

All three must pass for the canary to be promoted.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │    │   Prometheus    │    │   Dynatrace     │
│                 │    │                 │    │                 │
│   (Canary)      │◄──►│   (Scraping)    │    │   (APM Agent)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  │
               ┌─────────────────────────────────┐
               │             Flagger             │
               │                                 │
               │  MetricTemplate1 → Prometheus   │
               │  MetricTemplate2 → Dynatrace    │  
               │  MetricTemplate3 → Honeycomb    │
               │                                 │
               │  → Evaluates ALL metrics        │
               │  → Promotes if ALL pass         │
               └─────────────────────────────────┘
                                  │
                                  │
┌─────────────────┐    ┌─────────────────┐
│  OTel Collector │    │    Honeycomb    │
│                 │◄──►│                 │
│  (Scraping &    │    │   (Metrics      │
│   Forwarding)   │    │    Storage)     │
└─────────────────┘    └─────────────────┘
```

## Provider Definitions

The observability providers are configured in the following locations:

### Prometheus Provider
- **File**: `prometheus-config.yaml` (lines 7-9, 30-32, 46-48)
- **File**: `simple-metrics.yaml` (lines 7-9, 19-21, 31-33)
- **Configuration**:
  ```yaml
  provider:
    type: prometheus
    address: http://prometheus.istio-system:9090
  ```

### Dynatrace Provider  
- **File**: `dynatrace-secret.yaml` (lines 16-21, 35-40)
- **Configuration**:
  ```yaml
  provider:
    type: dynatrace
    address: https://{{ args.environment }}.live.dynatrace.com
    secretRef:
      name: dynatrace-secret
      key: api-token
  ```

### Honeycomb Provider
- **File**: `flagger-config.yaml` (lines 16-22, 34-40)  
- **File**: `otel-collector-config.yaml` (lines 114-120)
- **Configuration**:
  ```yaml
  provider:
    type: honeycomb
    address: https://api.honeycomb.io
    secretRef:
      name: honeycomb-secret
      key: api-key
  ```

### OpenTelemetry Collector
- **File**: `otel-collector-deployment.yaml` - Kubernetes deployment
- **File**: `otel-collector-config.yaml` - Collector configuration with Honeycomb exporter

## Files Overview

| File | Purpose |
|------|---------|
| `prometheus-config.yaml` | Prometheus metric templates for Flagger |
| `prometheus-scrape-config.yaml` | Complete Prometheus deployment with scraping configuration |
| `dynatrace-secret.yaml` | Dynatrace API credentials and metric templates |
| `canary-dual-metrics.yaml` | Example canary deployment using both metric providers |
| `simple-canary.yaml` | Simplified canary deployment with working metrics (recommended for testing) |
| `simple-metrics.yaml` | Simple metric templates using vector queries (guaranteed to work) |
| `flagger-config.yaml` | Main Flagger configuration |
| `otel-collector-config.yaml` | OpenTelemetry Collector configuration for Prometheus scraping |
| `otel-collector-deployment.yaml` | OpenTelemetry Collector deployment and RBAC |
| `honeycomb-otel-secret.yaml` | Honeycomb API credentials for OTel Collector |
| `setup-secrets.sh` | Automated setup script |
| `install-istio.sh` | Script to install Istio service mesh |
| `install-flagger.sh` | Script to install Flagger controller |
| `kind-config.yaml` | Configuration for Kind (Kubernetes in Docker) clusters |

## Prerequisites

- Docker Desktop with Kubernetes enabled (allocate at least 4GB RAM and 2 CPUs)
- `kubectl` configured to access your cluster
- Internet access for downloading components
- (Optional) Dynatrace APM with API access for dual metrics support

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
   
   This will set up Prometheus metrics and optionally configure Honeycomb via OpenTelemetry Collector. For Dynatrace integration, see the optional section below.

5. **Deploy the example canary:**
   ```bash
   # For testing/demo purposes (recommended):
   kubectl apply -f simple-canary.yaml
   
   # For production with real metrics:
   kubectl apply -f canary-dual-metrics.yaml
   ```

6. **Monitor the canary deployment:**
   ```bash
   kubectl get canaries -n test
   kubectl describe canary podinfo-canary -n test
   ```

## Optional: Enable Dynatrace Metrics

If you have a Dynatrace environment available, you can enable dual metrics support:

### 1. Uncomment Dynatrace Configuration

**In `setup-secrets.sh`:**
```bash
# Uncomment lines 12-18 and 21:
echo "Please provide your Dynatrace API token:"
read -s DYNATRACE_API_TOKEN
echo "Please provide your Dynatrace environment ID (e.g., abc12345):"
read DYNATRACE_ENVIRONMENT
kubectl create secret generic dynatrace-secret \
  --from-literal=api-token="$DYNATRACE_API_TOKEN" \
  --namespace=flagger-system

# And uncomment line 21:
kubectl apply -f dynatrace-secret.yaml
```

**In `canary-dual-metrics.yaml`:**
```bash
# Uncomment lines 43-56 (the Dynatrace metrics section)
```

### 2. Run Setup with Dynatrace

After uncommenting, run the setup script and it will prompt for your Dynatrace credentials:
```bash
./setup-secrets.sh
```

You'll need to provide:
- Dynatrace API token
- Dynatrace environment ID (e.g., abc12345)

### 3. Deploy with Dual Metrics

The canary deployment will then use both Prometheus and Dynatrace metrics for validation.

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

### Dynatrace Metrics (Optional)

When enabled, the Dynatrace configuration includes:

- **Success Rate**: Server-side error rate from Dynatrace APM
- **Latency**: Average response time from Dynatrace APM

**Note**: Dynatrace metrics are currently commented out. See the "Optional: Enable Dynatrace Metrics" section to enable them.

## Canary Analysis Process

1. **Traffic Split**: Flagger gradually shifts traffic from stable to canary version
2. **Metric Collection**: Both Prometheus and Dynatrace metrics are collected
3. **Threshold Validation**: All metrics must pass their thresholds
4. **Decision Making**: If any metric fails, the canary is rolled back
5. **Promotion**: If all metrics pass, the canary becomes the new stable version

## Customization

### Adjusting Thresholds

Edit the `thresholdRange` values in `canary-dual-metrics.yaml`:

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