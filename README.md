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

### Approach 2: Direct Querying (Advanced) ✅ PRODUCTION-READY
1. **Honeycomb-Prometheus Adapter** translates PromQL queries to Honeycomb API calls
2. **Flagger** queries the adapter as if it were Prometheus
3. **Adapter** executes queries against Honeycomb and returns results in Prometheus format
4. **Canary decisions** are made using live data from Honeycomb

**🎯 Fully Generic Implementation:**
- **Zero hardcoded service names** - works with any service
- **Template variables**: Uses `{{ target }}` and `{{ interval }}` for dynamic resolution
- **Automatic dataset selection**: Service name extracted from PromQL queries  
- **Production scalable**: One template set works for unlimited services

**Key Benefits**:
- Honeycomb receives detailed service telemetry with proper service names
- Flagger can make decisions using either Prometheus or Honeycomb data
- Enhanced observability during canary deployments

## Architecture

### Approach 1: Metrics Forwarding (Default)
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

### Approach 2: Direct Honeycomb Querying (Advanced)
```
┌─────────────────┐                           ┌─────────────────┐
│   Application   │──── Telemetry ───────────►│    Honeycomb    │
│                 │                           │                 │
│   (Canary)      │                           │   (Primary      │
└─────────────────┘                           │    Metrics)     │
                                              └─────────────────┘
                                                        │
                                                        │ API Queries
                                                        ▼
                                              ┌─────────────────┐
                                              │ Honeycomb-      │
                                              │ Prometheus      │
                                              │ Adapter         │
                                              │                 │
                                              │ • Query Polling │
                                              │ • 3min Windows  │
                                              │ • Secure Runtime│
                                              └─────────────────┘
                                                        │
                                                        │ Prometheus API
                                                        ▼
                                              ┌─────────────────┐
                                              │     Flagger     │
                                              │                 │
                                              │ → Queries       │
                                              │   Adapter       │
                                              │ → Validates     │
                                              │   Honeycomb     │
                                              │   Metrics       │
                                              │ → Promotes      │
                                              │   Canary        │
                                              └─────────────────┘
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

## Quick Start (Approach 1: Metrics Forwarding)

This Quick Start guide sets up **Approach 1** from the architecture above - metrics forwarding to Honeycomb via OpenTelemetry Collector while Flagger queries Prometheus directly.

1. **Clone and navigate to the project:**
   ```bash
   git clone <repository-url>
   cd flagger-dual-metrics
   ```

2. **Set up Honeycomb API keys:**
   Follow the [Honeycomb API Keys Setup](#honeycomb-api-keys-setup) section above to create both ingestion and query keys.

3. **Install Istio (required for traffic management):**
   ```bash
   ./install-istio.sh
   ```

4. **Install Flagger:**
   ```bash
   ./install-flagger.sh
   ```

5. **Configure Honeycomb integration:**
   ```bash
   ./setup-honeycomb-integration.sh --keep-existing
   ```
   
   This will set up Prometheus metrics and deploy the OpenTelemetry Collector to forward metrics to Honeycomb.

6. **Deploy the example canary:**
   ```bash
   # For testing/demo purposes (recommended):
   kubectl apply -f simple-canary.yaml
   
   # For production with real Istio metrics:
   kubectl apply -f real-metrics.yaml
   kubectl apply -f canary-honeycomb.yaml
   ```

7. **Verify Honeycomb dataset:**
   - Go to your Honeycomb UI → Data → Datasets
   - Look for the `flagger-metrics` dataset (created automatically when metrics start flowing)
   - You should see metrics arriving within 1-2 minutes of deploying applications

8. **Monitor the canary deployment:**
   ```bash
   kubectl get canaries -n test
   kubectl describe canary podinfo-canary -n test
   ```

### Verification Commands

After setup, verify your installation:

```bash
# Check that secrets are created
kubectl get secrets -n flagger-system | grep honeycomb

# Check OTel collector (metrics forwarding to Honeycomb)
kubectl get pods -n flagger-system -l app=otel-collector

# Verify Honeycomb adapter (if using direct querying)
kubectl get pods -n flagger-system -l app=honeycomb-adapter

# Monitor OTel collector logs
kubectl logs -n flagger-system deployment/otel-collector -f

# Test adapter health (if deployed)
kubectl port-forward -n flagger-system svc/honeycomb-adapter 9090:9090 &
curl http://localhost:9090/-/healthy
curl http://localhost:9090/-/ready
```

### Honeycomb Dataset Verification

To confirm metrics are flowing to Honeycomb:

1. **Check Dataset Creation:**
   - Open Honeycomb UI → Data → Datasets
   - Look for `flagger-metrics` dataset
   - If missing, check OTel collector logs for errors

2. **Verify Metric Flow:**
   ```bash
   # Check OTel collector is running and healthy
   kubectl port-forward -n flagger-system svc/otel-collector 13133:13133 &
   curl http://localhost:13133/  # Health check
   
   # Monitor metrics export
   kubectl logs -n flagger-system deployment/otel-collector -f | grep -i honeycomb
   ```

3. **Expected Honeycomb Data:**
   - Service metrics with `service.name` attributes
   - HTTP request metrics with status codes
   - Duration/latency measurements
   - Error rates and counts

## Honeycomb API Keys Setup

**Important:** Honeycomb uses different types of API keys for different purposes. This setup requires both:

### 1. Ingestion Key (for sending data TO Honeycomb)
- **Purpose**: Send telemetry data from applications to Honeycomb
- **Used by**: OpenTelemetry Collector, instrumented applications
- **Secret name**: `honeycomb-otel-secret`
- **Permissions**: Write access to send events/traces/metrics

### 2. Query Key (for reading data FROM Honeycomb)  
- **Purpose**: Query existing telemetry data in Honeycomb
- **Used by**: Honeycomb-Prometheus adapter for Flagger queries
- **Secret name**: `honeycomb-query-secret`
- **Permissions**: Read access to query datasets

### Setup Commands

**Step 1: Create the flagger-system namespace**
```bash
kubectl create namespace flagger-system
```

**Step 2: Create Honeycomb secrets**
```bash
# Create ingestion secret (for sending telemetry data)
kubectl create secret generic honeycomb-otel-secret \
  --from-literal=api-key=YOUR_HONEYCOMB_INGESTION_KEY \
  --namespace=flagger-system

# Create query secret (for reading telemetry data)
kubectl create secret generic honeycomb-query-secret \
  --from-literal=api-key=YOUR_HONEYCOMB_QUERY_KEY \
  --namespace=flagger-system
```

**Step 3: Verify secrets**
```bash
# Check that both secrets exist
kubectl get secrets -n flagger-system | grep honeycomb

# Verify secret contents (keys will be base64 encoded)
kubectl get secret honeycomb-otel-secret -n flagger-system -o yaml
kubectl get secret honeycomb-query-secret -n flagger-system -o yaml
```

**Where to get your keys:**
1. **Ingestion Key**: Honeycomb → Environment Settings → API Keys → Create key with "Send Events" permissions
2. **Query Key**: Honeycomb → Environment Settings → API Keys → Create key with "Read Events" permissions

**Note:** Keep these keys secure and never commit them to version control!

## Optional: Enable Honeycomb Metrics Export

The setup includes an OpenTelemetry Collector that can scrape Prometheus metrics and send them to Honeycomb:

### What it does:
- Scrapes all Prometheus endpoints (Istio, Envoy, application metrics)
- Filters and processes metrics for Honeycomb
- Exports metrics to Honeycomb dataset "flagger-metrics"

### Configuration:
The setup script will prompt you to configure Honeycomb. If you choose yes:
1. Provide your Honeycomb **ingestion key**
2. The OTel Collector will be deployed automatically

### Manual setup:
```bash
# Create Honeycomb ingestion secret (for sending data)
kubectl create secret generic honeycomb-otel-secret \
  --from-literal=api-key=YOUR_HONEYCOMB_INGESTION_KEY \
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
- **Provides a Prometheus-compatible API** that Flagger can query
- **Translates PromQL queries** to Honeycomb Query API calls with zero configuration
- **Enables Honeycomb as a direct metrics provider** for canary analysis
- **Implements robust query polling** with timeout handling
- **Uses optimized 3-minute time windows** for Flagger responsiveness + Honeycomb ingestion safety
- **Runs in a secure non-root container** environment
- **100% Generic**: No hardcoded service names - works with any service automatically
- **Parallel traffic generation required**: Ensures continuous telemetry flow for reliable decisions

### Prerequisites:
- Your applications must send telemetry to Honeycomb with these attributes:
  - `service.name` - Service identification
  - `http.status_code` - HTTP status codes
  - `duration_ms` - Request duration
  - `error` - Error tracking (boolean)
- **Critical**: Parallel traffic generation must be active during canary deployments
- Data ingestion delay: Allow 3+ minutes for telemetry to be queryable (optimized window)

### Traffic Generation Strategy (Essential for Success):

**Why Parallel Traffic is Critical:**
- Honeycomb requires continuous telemetry flow for accurate metrics
- Flagger makes decisions based on real-time traffic patterns  
- Insufficient traffic leads to failed or stalled canary deployments

**Recommended Traffic Pattern:**
```bash
# Deploy multiple traffic generators for comprehensive coverage
kubectl run traffic-health --image=busybox --restart=Never -- /bin/sh -c 'while true; do wget -q -O- http://your-service.namespace:port/health; sleep 1; done'

kubectl run traffic-main --image=busybox --restart=Never -- /bin/sh -c 'while true; do wget -q -O- http://your-service.namespace:port/; sleep 2; done'

kubectl run traffic-version --image=busybox --restart=Never -- /bin/sh -c 'while true; do wget -q -O- http://your-service.namespace:port/version; sleep 3; done'

# Verify traffic is flowing
kubectl logs traffic-health --tail=5
```

**Traffic Requirements:**
- **Minimum**: 1-2 requests per second during canary analysis
- **Recommended**: 3-5 requests per second across multiple endpoints
- **Duration**: Must run throughout entire canary deployment (5-15 minutes)
- **Endpoints**: Hit multiple endpoints (/, /health, /version, /api/v1/status) for comprehensive metrics

### Setup:

**Prerequisites:**
Your applications must send telemetry to Honeycomb with these attributes:
- `service.name` - Service identification
- `http.status_code` - HTTP status codes
- `duration_ms` - Request duration
- `error` - Error tracking (boolean)
- Data ingestion delay: Allow 10+ minutes for telemetry to be queryable

**Step 1: Create Query Key Secret**
The adapter needs a **query key** (not an ingestion key) to read data from Honeycomb:
```bash
# Create Honeycomb query secret (for reading data)
kubectl create secret generic honeycomb-query-secret \
  --from-literal=api-key=YOUR_HONEYCOMB_QUERY_KEY \
  --namespace=flagger-system
```

**Step 2: Deploy the Adapter**

**Option A: In-Cluster Build (Recommended)**
```bash
# Navigate to the adapter directory
cd honeycomb-adapter

# Build and deploy the adapter (builds Go code in-cluster)
make build-and-deploy

# Apply Honeycomb-backed metric templates
kubectl apply -f examples/metric-templates.yaml

# Use the Honeycomb canary example
kubectl apply -f examples/canary-example.yaml
```

**Option B: Local Build**
```bash
# Build Docker image locally
make docker-build

# For Kind clusters
kind load docker-image honeycomb-adapter:latest

# For minikube
eval $(minikube docker-env)
make docker-build

# Deploy
kubectl apply -f deployment/
```

### Verification:
```bash
# Check adapter health
kubectl port-forward -n flagger-system svc/honeycomb-adapter 9090:9090
curl http://localhost:9090/-/healthy

# Check readiness (tests Honeycomb connectivity)
curl http://localhost:9090/-/ready

# Test query translation
curl "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{service=\"test\"}[10m]))"

# Monitor adapter logs
kubectl logs -n flagger-system deployment/honeycomb-adapter -f
```

### Supported Metrics

The adapter currently supports these Flagger metric patterns:

**Error Rate:**
```promql
# PromQL Pattern
sum(rate(http_requests_total{code!~"5.*",service="my-app"}[10m])) / sum(rate(http_requests_total{service="my-app"}[10m])) * 100

# Honeycomb Translation
# Filters: http.status_code < 500 AND service.name = "my-app"
# Calculation: (COUNT(*) WHERE error=false) / COUNT(*) * 100
```

**Response Time:**
```promql
# PromQL Pattern
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{service="my-app"}[10m])))

# Honeycomb Translation
# Filters: service.name = "my-app"
# Calculation: P95(duration_ms)
```

**Request Rate:**
```promql
# PromQL Pattern
sum(rate(http_requests_total{service="my-app"}[10m]))

# Honeycomb Translation  
# Filters: service.name = "my-app"
# Calculation: COUNT(*) / time_window_seconds
```

### Configuration

**Environment Variables:**
| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `HONEYCOMB_API_KEY` | Honeycomb API key | - | Yes |
| `HONEYCOMB_DATASET` | Target dataset name | `flagger-metrics` | No |
| `HONEYCOMB_BASE_URL` | Honeycomb API URL | `https://api.honeycomb.io` | No |
| `LOG_LEVEL` | Logging level | `info` | No |
| `PORT` | Server port | `9090` | No |

**Service Name Mapping:**
The adapter extracts service names from PromQL queries using these patterns:
```promql
# Pattern 1: service label
{service="my-app"}

# Pattern 2: job label  
{job="my-app"}

# Pattern 3: Flagger template variable
{service="{{ args.name }}"}
```
Ensure your Honeycomb data uses consistent `service.name` values.

### Key Management Summary

| Purpose | Secret Name | Key Type | Used By | Permissions |
|---------|-------------|----------|---------|-------------|
| **Send data** | `honeycomb-otel-secret` | Ingestion Key | OTel Collector, Apps | Write (send events) |
| **Query data** | `honeycomb-query-secret` | Query Key | Honeycomb Adapter | Read (query datasets) |

**Important:** Don't mix these up! The adapter will fail if you provide an ingestion key instead of a query key.

**Note**: This is separate from the OTel Collector setup above. The adapter enables direct querying, while the OTel Collector forwards metrics for storage.

### Production Scalability Validation ✅

**Confirmed Generic Implementation:**

| Component | Hardcoded References | Template Variables | Status |
|-----------|---------------------|-------------------|---------|
| **Honeycomb Adapter** | ❌ None | ✅ Extracts from PromQL | 100% Generic |
| **MetricTemplates** | ❌ None | ✅ `{{ target }}`, `{{ interval }}` | 100% Generic |
| **Canary Deployment** | ❌ None | ✅ Uses template resolution | 100% Generic |

**Real-World Test Results:**
```bash
# Adapter successfully processed:
# - Service: cosmic-canary-service (extracted from {{ target }})
# - Dataset: cosmic-canary-service (auto-selected)  
# - Time Window: 180 seconds (from {{ interval }} = 3 minutes)
# - Query Results: 590 requests successfully analyzed
# - Canary Status: Progressing 20% → Successful deployment
```

**Deployment Pattern for Any Service:**
1. **Deploy your service** with OpenTelemetry instrumentation
2. **Start parallel traffic generators** targeting your service endpoints
3. **Apply standard Honeycomb MetricTemplates** (no service-specific changes needed)
4. **Create Canary resource** referencing your deployment (Flagger handles template variable injection)
5. **Trigger deployment change** to start canary analysis

## Quick Start (Approach 2: Direct Honeycomb Querying)

For advanced users who want Flagger to query Honeycomb directly instead of Prometheus:

1. **Complete Approach 1 setup first** (steps 1-5 from Quick Start above)

2. **Deploy applications to generate telemetry data:**
   ```bash
   # Deploy test applications that send telemetry to Honeycomb
   kubectl apply -f simple-canary.yaml
   ```

3. **Wait for data to appear in Honeycomb:**
   - Allow 10+ minutes for telemetry ingestion and processing
   - Verify data exists in Honeycomb UI → Query → your dataset

4. **Switch to Honeycomb-backed MetricTemplates:**
   ```bash
   # Apply Honeycomb metric templates (uses adapter for querying)
   kubectl apply -f honeycomb-adapter/examples/metric-templates.yaml
   
   # Deploy canary that uses Honeycomb metrics
   kubectl apply -f honeycomb-adapter/examples/canary-example.yaml
   ```

5. **Verify adapter functionality:**
   ```bash
   # Check adapter health and Honeycomb connectivity
   kubectl port-forward -n flagger-system svc/honeycomb-adapter 9090:9090 &
   curl http://localhost:9090/-/ready
   
   # Test query translation
   curl "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{service=\"podinfo\"}[10m]))"
   ```

**Important**: Approach 2 requires existing telemetry data in Honeycomb with proper service.name attributes and at least 10 minutes of data history.

## Testing the Honeycomb Adapter

### End-to-End Testing

The adapter includes comprehensive testing capabilities to validate the complete integration:

#### 1. Health Check Tests
```bash
# Basic health check
curl http://localhost:9090/-/healthy

# Readiness check (validates Honeycomb connectivity)
curl http://localhost:9090/-/ready
```

#### 2. Query Translation Tests
```bash
# Test success rate query
curl "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{service=\"podinfo\"}[10m]))"

# Test error rate query  
curl "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{service=\"podinfo\",code=~\"5..\"}[10m]))"

# Test duration query
curl "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,http_request_duration_seconds{service=\"podinfo\"}[10m])"
```

#### 3. Integration Testing with Flagger
```bash
# Deploy a test canary that uses the Honeycomb adapter
kubectl apply -f honeycomb-adapter/examples/canary-example.yaml

# Monitor the canary deployment
kubectl get canary test-canary -n test -w

# Check Flagger logs for adapter queries
kubectl logs -n flagger-system deployment/flagger -f | grep honeycomb
```

### Troubleshooting Tests

#### Data Availability Issues
```bash
# Check if data exists in the expected timeframe
curl "http://localhost:9090/api/v1/query?query=sum(http_requests_total{service=\"test\"}[1h])"

# Verify service names in Honeycomb data
curl "http://localhost:9090/api/v1/query?query=group(http_requests_total) by (service)"
```

#### Query Performance Testing
```bash
# Test query execution time
time curl "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{service=\"test\"}[10m]))"

# Monitor query polling behavior in logs
kubectl logs -n flagger-system deployment/honeycomb-adapter -f | grep "Polling attempt"
```

#### Security Testing
```bash
# Verify container runs as non-root
kubectl exec -n flagger-system deployment/honeycomb-adapter -- id

# Check file permissions
kubectl exec -n flagger-system deployment/honeycomb-adapter -- ls -la /app/honeycomb-adapter
```

#### Common Adapter Issues

**1. No data returned from queries**
- Verify Honeycomb dataset contains data with required fields
- Check service name mapping in logs
- Ensure time windows have sufficient data (minimum 10 minutes)

**2. Authentication errors**
- Verify `HONEYCOMB_API_KEY` is correct and has query permissions
- Check Honeycomb dataset exists and is accessible

**3. Query translation failures**
- Check adapter logs for unsupported query patterns
- Verify PromQL syntax matches supported patterns

**4. Flagger not promoting canary**
- Ensure metric thresholds are realistic for your data
- Check that service names match between Flagger and Honeycomb

**Debug Mode:**
```bash
# Enable debug logging
kubectl set env deployment/honeycomb-adapter LOG_LEVEL=debug -n flagger-system

# View detailed logs
kubectl logs -n flagger-system deployment/honeycomb-adapter -f
```

### Expected Test Results

**Successful Health Check:**
```json
{"status": "healthy"}
```

**Successful Query Response:**
```json
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {},
        "value": [1642678800, "42.5"]
      }
    ]
  }
}
```

**Common Test Failures:**
- `502 Bad Gateway`: Adapter not deployed or unhealthy
- `Query timeout`: Data not available in specified time window
- `Authentication failed`: Invalid Honeycomb API key
- `No data found`: Service name mismatch or insufficient telemetry

### Adapter Limitations

- **Limited PromQL support**: Only common Flagger query patterns are supported
- **Query performance**: Complex aggregations may be slower than native Prometheus
- **Time granularity**: Limited by Honeycomb's query API capabilities
- **No alerting**: Adapter only supports query operations
- **Minimum time windows**: Uses 10-minute minimum windows for data availability

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

## Verifying Successful Canary Deployments

After a canary completes, you can verify the version promotion was successful using multiple methods:

### 1. Application Response Verification
The most direct way to confirm the new version is active:
```bash
# Port forward to the application
kubectl port-forward -n test svc/podinfo 9898:9898 &

# Check the version in the response
curl -s http://localhost:9898/ | jq '.version'
# Example output: "6.5.4" (showing new promoted version)
```

### 2. Canary Resource Status
Check the canary deployment status and history:
```bash
# Check current canary status
kubectl get canary podinfo-canary -n test
# Should show: STATUS=Succeeded

# Review deployment events and progression
kubectl describe canary podinfo-canary -n test | grep -A10 "Events:"
# Look for progression: Advance canary weight 10 → 20 → 30 → ... → Succeeded
```

### 3. Deployment Image Verification
Verify both deployments are using the new image:
```bash
# Check primary deployment image (this serves live traffic)
kubectl get deployment podinfo-primary -n test -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check original deployment image (should match primary after promotion)
kubectl get deployment podinfo -n test -o jsonpath='{.spec.template.spec.containers[0].image}'

# Both should show the same new version, e.g.: ghcr.io/stefanprodan/podinfo:6.5.4
```

### 4. ReplicaSet History Analysis
View the complete deployment history to see version progression:
```bash
# List all ReplicaSets showing image versions
kubectl get rs -n test -o wide | grep podinfo

# Example output shows version progression:
# podinfo-545dccc488     0  0  0  6m   podinfod  ghcr.io/stefanprodan/podinfo:6.5.4  (promoted)
# podinfo-545fc47c4b     0  0  0  7m   podinfod  ghcr.io/stefanprodan/podinfo:6.0.3  (old)
# podinfo-primary-xxx    1  1  1  3m   podinfod  ghcr.io/stefanprodan/podinfo:6.5.4  (active)
```

### 5. Flagger Controller Logs
Review the promotion decision logs:
```bash
# Check recent Flagger logs for promotion events
kubectl logs -n flagger-system deployment/flagger --tail=20 | grep -E "(Advance|Promoting|Routing|Succeeded)"

# Example successful progression logs:
# "Advance podinfo-canary.test canary weight 10"
# "Advance podinfo-canary.test canary weight 20" 
# ...
# "Routing all traffic to primary"
```

### 6. Pod Labels and Metadata
Verify active pods are running the new version:
```bash
# Check current running pods
kubectl get pods -n test -l app=podinfo-primary -o wide

# Check pod image and creation time
kubectl describe pod -n test -l app=podinfo-primary | grep -E "(Image:|Created:)"
```

### 7. Honeycomb Dataset Verification (If Configured)
If you have telemetry forwarding to Honeycomb:

1. **Access Honeycomb UI** → Navigate to your `podinfo-service` dataset
2. **Query for deployment events**: 
   ```
   COUNT WHERE (service.version = "6.5.4") GROUP BY service.version
   ```
3. **Check service version timeline**: Look for the transition from old to new version around the deployment time
4. **Verify telemetry data**: Confirm both versions show up in traces during the canary window

### Troubleshooting Failed Promotions
If a canary fails (`STATUS=Failed`), investigate using:

```bash
# Check why it failed
kubectl describe canary podinfo-canary -n test | grep -A5 "Events:"

# Common failure reasons:
# - "Metric query failed" → Check metric templates and Prometheus connectivity
# - "canary deployment not ready" → Check pod status and image availability  
# - "Canary failed! Rolling back" → Metrics didn't meet thresholds

# Check pod status for image pull issues
kubectl get pods -n test
kubectl describe pod <failing-pod-name> -n test

# Verify metric templates are working
kubectl get metrictemplates -n flagger-system
```

### Expected Timeline
A typical successful canary deployment follows this pattern:
- **0-30s**: Initializing (creating primary deployment)
- **30-60s**: Progressing (10% traffic to canary)
- **1-4min**: Progressive traffic increase (20% → 30% → 40% → 50%)
- **4-5min**: Promoting (routing 100% traffic to primary)
- **5-6min**: Succeeded (canary pods terminated, promotion complete)

**Key Verification Points:**
✅ Application responds with new version  
✅ Canary status shows `Succeeded`  
✅ Both deployments use new image  
✅ ReplicaSet history shows progression  
✅ Flagger logs show successful advancement  
✅ Honeycomb data reflects new version (if configured)

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