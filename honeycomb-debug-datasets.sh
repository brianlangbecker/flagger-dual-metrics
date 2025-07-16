#!/bin/bash

# Debug script to check what datasets exist and their data
API_KEY="CbUVTd7D7rrdzvcV1FOu8B"
BASE_URL="https://api.honeycomb.io"

echo "🔍 DEBUGGING HONEYCOMB ACCESS"
echo "================================"
echo "API Key: ${API_KEY:0:12}..."
echo "Base URL: $BASE_URL"
echo ""

# Test 1: Try to list datasets (this might not work with this API key type)
echo "📋 Test 1: Checking API key access..."
curl -s -X GET "${BASE_URL}/1/datasets" \
  -H "X-Honeycomb-Team: ${API_KEY}" | jq .

echo ""
echo "📋 Test 2: Try different dataset names..."

# Test different possible dataset names
DATASETS=("cosmic-canary-service" "podinfo" "unknown" "default")

for dataset in "${DATASETS[@]}"; do
    echo ""
    echo "🔍 Testing dataset: $dataset"
    
    CREATE_RESPONSE=$(curl -s -X POST "${BASE_URL}/1/queries/${dataset}" \
      -H "Content-Type: application/json" \
      -H "X-Honeycomb-Team: ${API_KEY}" \
      -d '{
        "time_range": 28800,
        "calculations": [{"op": "COUNT"}],
        "orders": [{"op": "COUNT", "order": "descending"}]
      }')
    
    echo "Create response: $(echo "$CREATE_RESPONSE" | jq -c .)"
    
    QUERY_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
    
    if [ "$QUERY_ID" != "null" ] && [ -n "$QUERY_ID" ]; then
        echo "Query ID: $QUERY_ID"
        
        # Wait and execute
        sleep 2
        
        RESULT_RESPONSE=$(curl -s -X POST "${BASE_URL}/1/query_results/${dataset}" \
          -H "Content-Type: application/json" \
          -H "X-Honeycomb-Team: ${API_KEY}" \
          -d "{
            \"query_id\": \"${QUERY_ID}\",
            \"disable_series\": false,
            \"disable_total_by_aggregate\": true,
            \"disable_other_by_aggregate\": true,
            \"limit\": 10000
          }")
        
        COMPLETE=$(echo "$RESULT_RESPONSE" | jq -r '.complete')
        DATA=$(echo "$RESULT_RESPONSE" | jq '.data')
        
        if [ "$COMPLETE" == "true" ]; then
            if [ "$DATA" != "null" ]; then
                COUNT=$(echo "$DATA" | jq -r '.[0].COUNT // 0')
                echo "✅ $dataset: COUNT = $COUNT"
            else
                echo "❌ $dataset: COUNT = 0 (no data)"
            fi
        else
            echo "⏳ $dataset: Query still running"
        fi
    else
        echo "❌ $dataset: Failed to create query"
    fi
done

echo ""
echo "📋 Test 3: Check if the service is actually sending data..."
echo "Checking OTel collector logs..."