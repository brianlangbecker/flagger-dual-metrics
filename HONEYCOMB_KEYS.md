# Honeycomb API Keys Setup

This project requires **TWO DIFFERENT** Honeycomb API keys:

## 1. Ingest Key (hcaik_*)
- **Purpose**: Used by OpenTelemetry Collector to send traces/metrics TO Honeycomb
- **Format**: `hcaik_*` (Honeycomb API Ingest Key)
- **Permissions**: Write-only (can send data to Honeycomb)
- **Used by**: OpenTelemetry Collector
- **Secret**: `honeycomb-otel-secret`

## 2. Query Key (hcqk_*)
- **Purpose**: Used by Honeycomb Adapter to read data FROM Honeycomb for Flagger metrics
- **Format**: `hcqk_*` (Honeycomb Query Key)
- **Permissions**: Read-only (can query data from Honeycomb)
- **Used by**: Honeycomb Adapter
- **Secret**: `honeycomb-query-secret`

## Setup Instructions

### 1. Create Honeycomb Keys
In your Honeycomb dashboard:
1. Go to **Settings > API Keys**
2. Create an **Ingest Key** (starts with `hcaik_`) - for sending data
3. Create a **Query Key** (starts with `hcqk_`) - for reading data

### 2. Update Kubernetes Secrets

#### For Ingest Key (OpenTelemetry Collector):
```bash
kubectl create secret generic honeycomb-otel-secret \
  --from-literal=api-key="hcaik_your-ingest-key-here" \
  -n flagger-system
```

#### For Query Key (Honeycomb Adapter):
```bash
kubectl create secret generic honeycomb-query-secret \
  --from-literal=api-key="hcqk_your-query-key-here" \
  -n flagger-system
```

## Architecture Flow

```
┌─────────────────┐    ingest key     ┌─────────────┐
│   Instrumented  │ ──────────────────▶│             │
│   Application   │    (hcaik_*)      │             │
└─────────────────┘                   │             │
                                      │  Honeycomb  │
┌─────────────────┐    query key      │             │
│   Honeycomb     │ ◀──────────────────│             │
│   Adapter       │    (hcqk_*)       │             │
└─────────────────┘                   └─────────────┘
        │
        │ Prometheus metrics
        ▼
┌─────────────────┐
│    Flagger      │
└─────────────────┘
```

## Important Notes

- **Never use an ingest key for querying** - it won't work and will return 404 errors
- **Never use a query key for ingestion** - it won't have the right permissions
- Each key type has different permissions and endpoints in Honeycomb
- The OTel collector and adapter are completely separate components with different needs

## Troubleshooting

- **404 errors from Honeycomb Adapter**: Usually means you're using an ingest key instead of a query key
- **Authentication errors**: Check that your keys are correctly formatted and have the right permissions
- **No data in Honeycomb**: Check that the ingest key is working and traces are being sent