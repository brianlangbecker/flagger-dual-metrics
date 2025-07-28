# Honeycomb-Prometheus Adapter for Flagger

A translation service that enables Flagger to query Honeycomb using the familiar Prometheus API interface. This adapter allows you to use Honeycomb as a metrics provider for canary deployments without requiring custom Flagger builds.

## Overview

Flagger natively supports Prometheus but not Honeycomb. This adapter bridges that gap by:

1. **Exposing a Prometheus-compatible API** that Flagger can query
2. **Translating PromQL queries** to Honeycomb Query API calls
3. **Converting Honeycomb responses** back to Prometheus format
4. **Enabling Honeycomb-based canary analysis** with zero Flagger modifications

## Architecture

```
┌─────────────┐    ┌─────────────────────┐    ┌─────────────────┐
│   Flagger   │───►│  Honeycomb Adapter  │───►│   Honeycomb     │
│             │    │                     │    │                 │
│ (Prometheus │    │ Prometheus API ──►  │    │   Query API     │
│  queries)   │    │ Honeycomb queries   │    │                 │
└─────────────┘    └─────────────────────┘    └─────────────────┘
```

## Prerequisites

### Application Instrumentation
Your applications must send telemetry data to Honeycomb with the following attributes:

- **Service identification**: `service.name` field
- **HTTP status codes**: `http.status_code` field  
- **Request duration**: `duration_ms` field
- **Error tracking**: `error` boolean field

### OpenTelemetry Auto-Instrumentation (Recommended)
Use the OpenTelemetry Operator for automatic instrumentation:

```yaml
# Apply to your deployment
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-java: "honeycomb-instrumentation"
```

### Honeycomb Setup
- Honeycomb account with API access
- Dataset configured to receive telemetry data
- **Configuration API key** with "Run queries" permission (not an ingest key)

## Prerequisites Setup

### Step 1: Create Kubernetes namespace
```bash
kubectl create namespace flagger-system
```

### Step 2: Create Honeycomb configuration secret
```bash
# Create configuration secret (for reading telemetry data)
kubectl create secret generic honeycomb-query-secret \
  --from-literal=api-key=YOUR_HONEYCOMB_CONFIGURATION_KEY \
  --namespace=flagger-system
```

### Step 3: Verify secret
```bash
# Check that the secret exists
kubectl get secret honeycomb-query-secret -n flagger-system

# Verify secret contents (key will be base64 encoded)
kubectl get secret honeycomb-query-secret -n flagger-system -o yaml
```

**Where to get your Configuration API key:**
- Go to Honeycomb → Environment Settings → API Keys
- Create a new **Configuration API key** with "Run queries" permission
- **Important:** Do not use an Ingest key - the adapter needs query permissions only
- **Security:** Configuration keys can have granular permissions - only enable "Run queries" for this use case

## Quick Start

### 1. Deploy the Adapter

**Option A: In-Cluster Build (Recommended)**
```bash
# Clone this repository
git clone <repository-url>
cd honeycomb-adapter

# Build and deploy (compiles Go code in-cluster)
make build-and-deploy
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

### 2. Configure Secrets (if not already done)

If you haven't already created the secret in the Prerequisites Setup section:

```bash
# Create Honeycomb Configuration API secret (requires "Run queries" permission)
kubectl create secret generic honeycomb-query-secret \
  --from-literal=api-key=YOUR_HONEYCOMB_CONFIGURATION_KEY \
  --namespace=flagger-system
```

**Important:** Use a **Configuration API key** with "Run queries" permission, not an Ingest key. The adapter needs query permissions to read existing telemetry data in Honeycomb.

### 3. Create MetricTemplates

```bash
# Apply Honeycomb-backed metric templates
kubectl apply -f examples/metric-templates.yaml
```

### 4. Deploy Canary

```bash
# Use the example canary configuration
kubectl apply -f examples/canary-example.yaml
```

## Supported Metrics

The adapter currently supports these Flagger metric patterns:

### Error Rate
**PromQL Pattern:**
```promql
sum(rate(http_requests_total{code!~"5.*",service="my-app"}[5m])) / sum(rate(http_requests_total{service="my-app"}[5m])) * 100
```

**Honeycomb Translation:**
- Filters: `http.status_code < 500` AND `service.name = "my-app"`
- Calculation: `(COUNT(*) WHERE error=false) / COUNT(*) * 100`

### Response Time
**PromQL Pattern:**
```promql
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{service="my-app"}[5m])))
```

**Honeycomb Translation:**
- Filters: `service.name = "my-app"`
- Calculation: `P95(duration_ms)`

### Request Rate
**PromQL Pattern:**
```promql
sum(rate(http_requests_total{service="my-app"}[5m]))
```

**Honeycomb Translation:**
- Filters: `service.name = "my-app"`
- Calculation: `COUNT(*) / time_window_seconds`

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `HONEYCOMB_API_KEY` | Honeycomb **Configuration API key** | - | Yes |
| `HONEYCOMB_DATASET` | Target dataset name | `flagger-metrics` | No |
| `HONEYCOMB_BASE_URL` | Honeycomb API URL | `https://api.honeycomb.io` | No |
| `QUERY_TIME_WINDOW` | Minimum query time window | `3m` | No |
| `LOG_LEVEL` | Logging level | `info` | No |
| `PORT` | Server port | `9090` | No |

**Note:** The `HONEYCOMB_API_KEY` must be a **Configuration API key** with "Run queries" permission, not an Ingest key.

### Query Time Window Configuration

The `QUERY_TIME_WINDOW` environment variable controls the minimum time window for Honeycomb queries. This setting is important for balancing query performance with data freshness.

**Format:** Go duration format (e.g., `3m`, `5m`, `30s`, `1h`)

**Behavior:**
- If a PromQL query specifies a time window (e.g., `[5m]`), that window is used if it's >= the configured minimum
- If a PromQL query specifies a smaller window (e.g., `[30s]` when minimum is `3m`), the minimum is enforced
- If no time window is specified in the query, the configured minimum is used

**Examples:**
```bash
# Set 5-minute minimum window
QUERY_TIME_WINDOW=5m

# Set 30-second minimum (faster but may miss recent data)
QUERY_TIME_WINDOW=30s

# Set 1-hour minimum (slower but more comprehensive)
QUERY_TIME_WINDOW=1h
```

**Considerations:**
- **Shorter windows (< 3m)**: Faster queries but may miss recent data due to Honeycomb ingestion delays
- **Longer windows (> 5m)**: More comprehensive data but slower canary analysis cycles
- **Default (3m)**: Balanced approach optimized for Flagger's typical canary deployment timings

**Invalid values** (e.g., `invalid-duration`) will log a warning and default to `3m`.

### Service Name Mapping

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

## Development

### Building Locally

```bash
# Build the Go binary
go build -o honeycomb-adapter .

# Run locally
export HONEYCOMB_API_KEY=your-key
export HONEYCOMB_DATASET=your-dataset
export QUERY_TIME_WINDOW=3m  # Optional: set custom time window
./honeycomb-adapter
```

### Testing

```bash
# Run unit tests
go test ./...

# Test Prometheus API endpoint
curl "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{service=\"test\"}[5m]))"

# Test health endpoint
curl http://localhost:9090/-/healthy
```

### Docker Build

```bash
# Build Docker image
docker build -t honeycomb-adapter:latest .

# Run container
docker run -p 9090:9090 \
  -e HONEYCOMB_API_KEY=your-key \
  -e HONEYCOMB_DATASET=your-dataset \
  -e QUERY_TIME_WINDOW=3m \
  honeycomb-adapter:latest
```

## Examples

### Complete Canary Setup

See `examples/` directory for:
- `metric-templates.yaml` - Honeycomb-backed MetricTemplates
- `canary-example.yaml` - Sample canary deployment
- `instrumentation.yaml` - OpenTelemetry auto-instrumentation config

### Testing Queries

```bash
# Test error rate query
curl "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{code!~\"5.*\",service=\"my-app\"}[5m]))/sum(rate(http_requests_total{service=\"my-app\"}[5m]))*100"

# Test latency query  
curl "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,sum(rate(http_request_duration_seconds_bucket{service=\"my-app\"}[5m])))"
```

## Troubleshooting

### Common Issues

**1. No data returned from queries**
- Verify Honeycomb dataset contains data with required fields
- Check service name mapping in logs
- Ensure time windows have sufficient data

**2. Authentication errors**
- Verify `HONEYCOMB_API_KEY` is a **Configuration API key** (not Ingest key) with "Run queries" permission
- Check Honeycomb dataset exists and is accessible
- Confirm the Configuration key has access to the specific dataset being queried
- **Security:** Ensure only minimal permissions are granted - just "Run queries"

**3. Query translation failures**
- Check adapter logs for unsupported query patterns
- Verify PromQL syntax matches supported patterns

**4. Flagger not promoting canary**
- Ensure metric thresholds are realistic for your data
- Check that service names match between Flagger and Honeycomb

**5. Slow canary analysis cycles**
- Consider reducing `QUERY_TIME_WINDOW` (e.g., `1m`) for faster analysis
- Balance between speed and data completeness based on your ingestion patterns

**6. Missing recent data in queries**
- Increase `QUERY_TIME_WINDOW` (e.g., `5m`) to account for ingestion delays
- Check Honeycomb ingestion latency for your data pipeline

### Debug Mode

```bash
# Enable debug logging
kubectl set env deployment/honeycomb-adapter LOG_LEVEL=debug -n flagger-system

# View detailed logs
kubectl logs -n flagger-system deployment/honeycomb-adapter -f
```

### Health Checks

```bash
# Check adapter health
kubectl port-forward -n flagger-system svc/honeycomb-adapter 9090:9090
curl http://localhost:9090/-/healthy

# Verify Honeycomb connectivity
curl http://localhost:9090/-/ready
```

## Limitations

- **Limited PromQL support**: Only common Flagger query patterns are supported
- **Query performance**: Complex aggregations may be slower than native Prometheus
- **Time granularity**: Limited by Honeycomb's query API capabilities
- **No alerting**: Adapter only supports query operations

## Extending Support

To add support for new query patterns:

1. Add pattern recognition in `translatePromQLToHoneycomb()`
2. Implement Honeycomb query translation
3. Add corresponding tests
4. Update documentation

Example:
```go
// Add to translation function
if strings.Contains(promQL, "your_metric_pattern") {
    return &HoneycombQuery{
        Calculations: []Calculation{{Op: "AVG", Column: "your_field"}},
        Filters: []Filter{{Column: "service.name", Op: "=", Value: serviceName}},
    }, nil
}
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review adapter logs for error details
3. Verify Honeycomb data structure matches requirements
4. Open an issue with query examples and error messages

## Related Projects

- [Flagger](https://flagger.app/) - Progressive delivery operator
- [OpenTelemetry](https://opentelemetry.io/) - Observability framework
- [Honeycomb](https://honeycomb.io/) - Observability platform