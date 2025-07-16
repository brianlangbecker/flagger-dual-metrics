#!/bin/bash

# Verbose debug script with all logging
API_KEY="CbUVTd7D7rrdzvcV1FOu8B"
DATASET="cosmic-canary-service"
BASE_URL="https://api.honeycomb.io"

echo "🔍 VERBOSE HONEYCOMB DEBUG - 8 HOURS"
echo "=================================="
echo "API Key: $API_KEY"
echo "Dataset: $DATASET"
echo "Base URL: $BASE_URL"
echo "Full URL: ${BASE_URL}/1/queries/${DATASET}"
echo "Current time: $(date)"
echo ""

# The exact query we're sending
QUERY_BODY='{
  "time_range": 28800,
  "calculations": [{"op": "COUNT"}],
  "orders": [{"op": "COUNT", "order": "descending"}]
}'

echo "📋 STEP 1: CREATE QUERY"
echo "======================"
echo "Request URL: ${BASE_URL}/1/queries/${DATASET}"
echo "Request Method: POST"
echo "Request Headers:"
echo "  Content-Type: application/json"
echo "  X-Honeycomb-Team: $API_KEY"
echo "Request Body:"
echo "$QUERY_BODY" | jq .
echo ""

echo "🚀 Sending create query request..."
CREATE_RESPONSE=$(curl -v -X POST "${BASE_URL}/1/queries/${DATASET}" \
  -H "Content-Type: application/json" \
  -H "X-Honeycomb-Team: ${API_KEY}" \
  -d "$QUERY_BODY" 2>&1)

echo "📥 CREATE RESPONSE (raw):"
echo "$CREATE_RESPONSE"
echo ""

# Extract just the JSON part
JSON_RESPONSE=$(echo "$CREATE_RESPONSE" | tail -n 1)
echo "📥 CREATE RESPONSE (JSON):"
echo "$JSON_RESPONSE" | jq .
echo ""

QUERY_ID=$(echo "$JSON_RESPONSE" | jq -r '.id')
echo "🆔 Extracted Query ID: $QUERY_ID"

if [ "$QUERY_ID" == "null" ] || [ -z "$QUERY_ID" ]; then
    echo "❌ Failed to get query ID!"
    exit 1
fi

echo ""
echo "📋 STEP 2: EXECUTE QUERY"
echo "======================"
echo "Request URL: ${BASE_URL}/1/query_results/${DATASET}"
echo "Request Method: POST"
echo "Request Headers:"
echo "  Content-Type: application/json"
echo "  X-Honeycomb-Team: $API_KEY"

EXEC_BODY="{
  \"query_id\": \"${QUERY_ID}\",
  \"disable_series\": false,
  \"disable_total_by_aggregate\": true,
  \"disable_other_by_aggregate\": true,
  \"limit\": 10000
}"

echo "Request Body:"
echo "$EXEC_BODY" | jq .
echo ""

echo "🚀 Sending execute query request..."
EXEC_RESPONSE=$(curl -v -X POST "${BASE_URL}/1/query_results/${DATASET}" \
  -H "Content-Type: application/json" \
  -H "X-Honeycomb-Team: ${API_KEY}" \
  -d "$EXEC_BODY" 2>&1)

echo "📥 EXECUTE RESPONSE (raw):"
echo "$EXEC_RESPONSE"
echo ""

# Extract just the JSON part
JSON_EXEC_RESPONSE=$(echo "$EXEC_RESPONSE" | tail -n 1)
echo "📥 EXECUTE RESPONSE (JSON):"
echo "$JSON_EXEC_RESPONSE" | jq .
echo ""

# Parse the results
COMPLETE=$(echo "$JSON_EXEC_RESPONSE" | jq -r '.complete')
DATA=$(echo "$JSON_EXEC_RESPONSE" | jq '.data')

echo "🔍 ANALYSIS"
echo "==========="
echo "Query Complete: $COMPLETE"
echo "Data field present: $([ "$DATA" != "null" ] && echo "YES" || echo "NO")"
echo "Data field value: $DATA"

if [ "$DATA" != "null" ]; then
    COUNT=$(echo "$DATA" | jq -r '.[0].COUNT // 0')
    echo "✅ COUNT RESULT: $COUNT"
    
    echo ""
    echo "📊 DETAILED DATA:"
    echo "$DATA" | jq .
else
    echo "❌ COUNT RESULT: 0 (no data field)"
fi

echo ""
echo "🌐 Honeycomb UI Link:"
echo "https://ui.honeycomb.io/beowulf/environments/advanced/datasets/${DATASET}/result/${QUERY_ID}"