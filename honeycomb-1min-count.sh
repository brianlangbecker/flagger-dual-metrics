#!/bin/bash

# Simple 1-minute count query to catch fresh data
API_KEY="CbUVTd7D7rrdzvcV1FOu8B"
DATASET="cosmic-canary-service"
BASE_URL="https://api.honeycomb.io"

echo "🚀 Creating 1-minute COUNT query..."
echo "Dataset: $DATASET"
echo ""

# 1-minute query - just count everything in the dataset
CREATE_RESPONSE=$(curl -s -X POST "${BASE_URL}/1/queries/${DATASET}" \
  -H "Content-Type: application/json" \
  -H "X-Honeycomb-Team: ${API_KEY}" \
  -d '{
    "time_range": 60,
    "calculations": [{"op": "COUNT"}],
    "orders": [{"op": "COUNT", "order": "descending"}]
  }')

echo "📋 Query creation response:"
echo "$CREATE_RESPONSE" | jq .

QUERY_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')

if [ "$QUERY_ID" == "null" ] || [ -z "$QUERY_ID" ]; then
    echo "❌ Failed to get query ID"
    exit 1
fi

echo "🆔 Query ID: $QUERY_ID"
echo ""
echo "⏳ Waiting 1 second..."
sleep 1

# Execute the query
RESULT_RESPONSE=$(curl -s -X POST "${BASE_URL}/1/query_results/${DATASET}" \
  -H "Content-Type: application/json" \
  -H "X-Honeycomb-Team: ${API_KEY}" \
  -d "{
    \"query_id\": \"${QUERY_ID}\",
    \"disable_series\": false,
    \"disable_total_by_aggregate\": true,
    \"disable_other_by_aggregate\": true,
    \"limit\": 10000
  }")

echo "📊 Query execution response:"
echo "$RESULT_RESPONSE" | jq .

DATA=$(echo "$RESULT_RESPONSE" | jq '.data')
COMPLETE=$(echo "$RESULT_RESPONSE" | jq -r '.complete')

echo ""
echo "=== RESULTS (1 minute) ==="
echo "Complete: $COMPLETE"

if [ "$COMPLETE" == "true" ]; then
    if [ "$DATA" != "null" ]; then
        COUNT=$(echo "$DATA" | jq -r '.[0].COUNT // 0')
        echo "✅ COUNT: $COUNT"
    else
        echo "❌ COUNT: 0 (no data)"
    fi
else
    echo "⏳ Query still running"
fi