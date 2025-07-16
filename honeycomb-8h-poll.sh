#!/bin/bash

# 8-hour count query with polling until complete
API_KEY="CbUVTd7D7rrdzvcV1FOu8B"
DATASET="cosmic-canary-service"
BASE_URL="https://api.honeycomb.io"

echo "🚀 Creating 8-hour COUNT query..."
echo "Dataset: $DATASET"
echo ""

# 8-hour query - count everything in the dataset
CREATE_RESPONSE=$(curl -s -X POST "${BASE_URL}/1/queries/${DATASET}" \
  -H "Content-Type: application/json" \
  -H "X-Honeycomb-Team: ${API_KEY}" \
  -d '{
    "time_range": 28800,
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
echo "⏳ Polling until query completes..."

# Poll until complete
MAX_ATTEMPTS=20
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Poll attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
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

    COMPLETE=$(echo "$RESULT_RESPONSE" | jq -r '.complete')
    
    if [ "$COMPLETE" == "true" ]; then
        echo "✅ Query completed!"
        echo ""
        echo "📊 Final response:"
        echo "$RESULT_RESPONSE" | jq .
        
        DATA=$(echo "$RESULT_RESPONSE" | jq '.data')
        
        echo ""
        echo "=== FINAL RESULTS (8 hours) ==="
        if [ "$DATA" != "null" ]; then
            COUNT=$(echo "$DATA" | jq -r '.[0].COUNT // 0')
            echo "✅ COUNT: $COUNT"
        else
            echo "❌ COUNT: 0 (no data field)"
        fi
        exit 0
    else
        echo "Still running... waiting 3 seconds"
        sleep 3
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
done

echo "❌ Query did not complete after $MAX_ATTEMPTS attempts"
echo "Last response:"
echo "$RESULT_RESPONSE" | jq .