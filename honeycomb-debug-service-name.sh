#!/bin/bash

# Debug script to check exact service name values
API_KEY="CbUVTd7D7rrdzvcV1FOu8B"
DATASET="cosmic-canary-service"
BASE_URL="https://api.honeycomb.io"

echo "🚀 Creating query to get raw service.name values..."

# Query to get the first few events with service.name field
CREATE_RESPONSE=$(curl -s -X POST "${BASE_URL}/1/queries/${DATASET}" \
  -H "Content-Type: application/json" \
  -H "X-Honeycomb-Team: ${API_KEY}" \
  -d '{
    "time_range": 28800,
    "calculations": [{"op": "COUNT"}],
    "breakdowns": ["service.name"],
    "orders": [{"op": "COUNT", "order": "descending"}],
    "limit": 5
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
echo "⏳ Waiting 3 seconds for query to complete..."
sleep 3

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
echo "=== DEBUG RESULTS ==="
echo "Complete: $COMPLETE"

if [ "$COMPLETE" == "true" ] && [ "$DATA" != "null" ]; then
    echo "🔍 Found service names with character analysis:"
    echo "$DATA" | jq -r '.[] | "Service: [\(.["service.name"])] Length: \(.["service.name"] | length) Count: \(.COUNT)"'
    
    echo ""
    echo "🔍 Checking for exact match with 'cosmic-canary-service':"
    echo "$DATA" | jq -r '.[] | select(.["service.name"] == "cosmic-canary-service") | "✅ EXACT MATCH FOUND: Count = \(.COUNT)"'
    
    echo ""
    echo "🔍 All service names (with quotes to see whitespace):"
    echo "$DATA" | jq -r '.[] | "\"" + .["service.name"] + "\""'
    
else
    echo "⏳ Query not complete yet or no data. Complete: $COMPLETE"
fi