#!/bin/bash

# Debug script to show exact query details
API_KEY="CbUVTd7D7rrdzvcV1FOu8B"
DATASET="cosmic-canary-service"
BASE_URL="https://api.honeycomb.io"

echo "🔍 HONEYCOMB QUERY DEBUG INFO"
echo "================================="
echo "API Key: ${API_KEY:0:12}..."
echo "Dataset: $DATASET"
echo "Base URL: $BASE_URL"
echo "Full URL: ${BASE_URL}/1/queries/${DATASET}"
echo ""

# The query we're sending
QUERY_BODY='{
  "time_range": 28800,
  "calculations": [{"op": "COUNT"}],
  "filters": [{"column": "service.name", "op": "=", "value": "cosmic-canary-service"}],
  "orders": [{"op": "COUNT", "order": "descending"}]
}'

echo "📋 QUERY BODY:"
echo "$QUERY_BODY" | jq .
echo ""

echo "🚀 Creating query..."
echo "curl -X POST \"${BASE_URL}/1/queries/${DATASET}\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -H \"X-Honeycomb-Team: ${API_KEY}\" \\"
echo "  -d '$QUERY_BODY'"
echo ""

CREATE_RESPONSE=$(curl -s -X POST "${BASE_URL}/1/queries/${DATASET}" \
  -H "Content-Type: application/json" \
  -H "X-Honeycomb-Team: ${API_KEY}" \
  -d "$QUERY_BODY")

echo "📋 CREATE RESPONSE:"
echo "$CREATE_RESPONSE" | jq .
echo ""

QUERY_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')

if [ "$QUERY_ID" == "null" ] || [ -z "$QUERY_ID" ]; then
    echo "❌ Failed to get query ID"
    exit 1
fi

echo "🆔 Query ID: $QUERY_ID"
echo ""

# The execution query
EXEC_BODY="{
  \"query_id\": \"${QUERY_ID}\",
  \"disable_series\": false,
  \"disable_total_by_aggregate\": true,
  \"disable_other_by_aggregate\": true,
  \"limit\": 10000
}"

echo "📋 EXECUTION BODY:"
echo "$EXEC_BODY" | jq .
echo ""

echo "🔍 Executing query..."
echo "curl -X POST \"${BASE_URL}/1/query_results/${DATASET}\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -H \"X-Honeycomb-Team: ${API_KEY}\" \\"
echo "  -d '$EXEC_BODY'"
echo ""

RESULT_RESPONSE=$(curl -s -X POST "${BASE_URL}/1/query_results/${DATASET}" \
  -H "Content-Type: application/json" \
  -H "X-Honeycomb-Team: ${API_KEY}" \
  -d "$EXEC_BODY")

echo "📊 EXECUTION RESPONSE:"
echo "$RESULT_RESPONSE" | jq .
echo ""

# Parse results
DATA=$(echo "$RESULT_RESPONSE" | jq '.data')
COMPLETE=$(echo "$RESULT_RESPONSE" | jq -r '.complete')

echo "=== FINAL ANALYSIS ==="
echo "Query Complete: $COMPLETE"
echo "Data Field Present: $([ "$DATA" != "null" ] && echo "YES" || echo "NO")"

if [ "$DATA" != "null" ]; then
    COUNT=$(echo "$DATA" | jq -r '.[0].COUNT // 0')
    echo "Count Result: $COUNT"
else
    echo "Count Result: 0 (no data field)"
fi

echo ""
echo "🌐 UI Link: https://ui.honeycomb.io/beowulf/environments/advanced/datasets/${DATASET}/result/${QUERY_ID}"