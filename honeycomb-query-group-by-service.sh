#!/bin/bash

# Honeycomb Query Test Script - GROUP BY SERVICE NAME
# This script finds what service names actually exist

API_KEY="CbUVTd7D7rrdzvcV1FOu8B"
DATASET="cosmic-canary-service"
BASE_URL="https://api.honeycomb.io"

echo "🚀 Creating Honeycomb query to find actual service names..."

# Step 1: Create the query with GROUP BY service.name
CREATE_RESPONSE=$(curl -s -X POST "${BASE_URL}/1/queries/${DATASET}" \
  -H "Content-Type: application/json" \
  -H "X-Honeycomb-Team: ${API_KEY}" \
  -d '{
    "time_range": 28800,
    "calculations": [{"op": "COUNT"}],
    "breakdowns": ["service.name"],
    "orders": [{"op": "COUNT", "order": "descending"}]
  }')

echo "📋 Query creation response:"
echo "$CREATE_RESPONSE" | jq .

# Extract the query ID
QUERY_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')

if [ "$QUERY_ID" == "null" ] || [ -z "$QUERY_ID" ]; then
    echo "❌ Failed to get query ID"
    exit 1
fi

echo "🆔 Query ID: $QUERY_ID"
echo ""
echo "🔍 Executing query..."

# Step 2: Execute the query
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

# Extract the data field specifically
DATA=$(echo "$RESULT_RESPONSE" | jq '.data')
COMPLETE=$(echo "$RESULT_RESPONSE" | jq -r '.complete')

echo ""
echo "=== RESULTS SUMMARY ==="
echo "Complete: $COMPLETE"

if [ "$COMPLETE" == "true" ]; then
    if [ "$DATA" == "null" ]; then
        echo "❌ No data returned"
    else
        echo "✅ Data found! Here are the actual service names:"
        echo "$DATA" | jq -r '.[] | "Service: \(.["service.name"] // "null"), Count: \(.COUNT)"'
    fi
else
    echo "⏳ Query still running - try again in a moment"
fi