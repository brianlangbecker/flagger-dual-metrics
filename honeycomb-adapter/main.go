package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type HoneycombAdapter struct {
	honeycombAPIKey  string
	honeycombDataset string
	honeycombBaseURL string
	logLevel         string
}

type PrometheusResponse struct {
	Status string `json:"status"`
	Data   struct {
		ResultType string `json:"resultType"`
		Result     []struct {
			Metric map[string]string `json:"metric"`
			Value  []interface{}     `json:"value"`
		} `json:"result"`
	} `json:"data"`
}

type HoneycombQuery struct {
	TimeRange    int           `json:"time_range"`  // Changed to int (seconds)
	Granularity  int          `json:"granularity,omitempty"`
	Calculations []Calculation `json:"calculations"`
	Filters      []Filter     `json:"filters,omitempty"`
	Orders       []Order      `json:"orders,omitempty"`
}

type Calculation struct {
	Op     string `json:"op"`
	Column string `json:"column,omitempty"`
}

type Filter struct {
	Column string      `json:"column"`
	Op     string      `json:"op"`
	Value  interface{} `json:"value"`
}

type Order struct {
	Op    string `json:"op"`
	Order string `json:"order"`
}

type TimeRange struct {
	StartTime int64 `json:"start_time"`
	EndTime   int64 `json:"end_time"`
}

func main() {
	adapter := &HoneycombAdapter{
		honeycombAPIKey:  getEnv("HONEYCOMB_API_KEY", ""),
		honeycombDataset: getEnv("HONEYCOMB_DATASET", ""),
		honeycombBaseURL: getEnv("HONEYCOMB_BASE_URL", "https://api.honeycomb.io"),
		logLevel:         getEnv("LOG_LEVEL", "info"),
	}

	if adapter.honeycombAPIKey == "" {
		log.Fatal("HONEYCOMB_API_KEY environment variable is required")
	}

	log.Printf("🔑 API Key: %s", adapter.honeycombAPIKey[:8]+"...") // Show first 8 chars
	log.Printf("🔧 Log Level: %s", adapter.logLevel)

	http.HandleFunc("/api/v1/query", adapter.handleQuery)
	http.HandleFunc("/api/v1/query_range", adapter.handleQueryRange)
	http.HandleFunc("/-/healthy", adapter.handleHealth)
	http.HandleFunc("/-/ready", adapter.handleReady)

	port := getEnv("PORT", "9090")
	log.Printf("🚀 Starting Honeycomb-Prometheus adapter on port %s", port)
	log.Printf("🌐 Base URL: %s", adapter.honeycombBaseURL)
	log.Printf("📋 Endpoints:")
	log.Printf("  - GET /api/v1/query - Query endpoint")
	log.Printf("  - GET /-/healthy - Health check")
	log.Printf("  - GET /-/ready - Readiness check")
	log.Printf("✅ Adapter ready to receive requests!")
	
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func (h *HoneycombAdapter) handleQuery(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("query")
	timeParam := r.URL.Query().Get("time")

	log.Printf("🔍 Received PromQL query: %s", query)
	h.logDebug("Received query: %s", query)

	if query == "" {
		http.Error(w, "query parameter is required", http.StatusBadRequest)
		return
	}

	// Parse the PromQL query and convert to Honeycomb query
	honeycombQuery, err := h.translatePromQLToHoneycomb(query)
	if err != nil {
		log.Printf("❌ Query translation error: %v", err)
		h.logError("Query translation error: %v", err)
		http.Error(w, fmt.Sprintf("Query translation error: %v", err), http.StatusBadRequest)
		return
	}

	log.Printf("🔄 Translated to Honeycomb query: %+v", honeycombQuery)
	h.logDebug("Translated to Honeycomb query: %+v", honeycombQuery)

	// Execute Honeycomb query
	serviceName := h.extractServiceName(query)
	result, err := h.executeHoneycombQuery(honeycombQuery, serviceName)
	if err != nil {
		log.Printf("❌ Honeycomb query error: %v", err)
		h.logError("Honeycomb query error: %v", err)
		http.Error(w, fmt.Sprintf("Honeycomb query error: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("✅ Honeycomb result: %+v", result)
	h.logDebug("Honeycomb result: %+v", result)

	// Convert Honeycomb result to Prometheus format
	promResponse := h.convertToPrometheusFormat(result, timeParam)
	log.Printf("📊 Returning Prometheus response: %+v", promResponse)

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(promResponse); err != nil {
		log.Printf("❌ Response encoding error: %v", err)
		h.logError("Response encoding error: %v", err)
		http.Error(w, "Internal server error", http.StatusInternalServerError)
	}
}

func (h *HoneycombAdapter) handleQueryRange(w http.ResponseWriter, r *http.Request) {
	// For simplicity, delegate to handleQuery for now
	// In production, you might want to implement proper range queries
	h.handleQuery(w, r)
}

func (h *HoneycombAdapter) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}

func (h *HoneycombAdapter) handleReady(w http.ResponseWriter, r *http.Request) {
	// Test Honeycomb connectivity
	testQuery := &HoneycombQuery{
		TimeRange: 60, // 1 minute in seconds
		Calculations: []Calculation{{Op: "COUNT"}},
	}

	_, err := h.executeHoneycombQuery(testQuery, "test")
	if err != nil {
		h.logError("Readiness check failed: %v", err)
		http.Error(w, "Not ready", http.StatusServiceUnavailable)
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Ready"))
}

func (h *HoneycombAdapter) translatePromQLToHoneycomb(promQL string) (*HoneycombQuery, error) {
	timeWindow := h.extractTimeWindow(promQL)

	baseQuery := &HoneycombQuery{
		TimeRange: int(timeWindow.Seconds()), // Convert to seconds
		Filters: []Filter{},
		Orders: []Order{{Op: "COUNT", Order: "descending"}},
	}

	// No need to add service filter - dataset name already identifies the service
	// The service name is used as the dataset in the URL: /1/queries/{serviceName}

	// Error rate query pattern
	if strings.Contains(promQL, "http_requests_total") && strings.Contains(promQL, "code!~\"5.*\"") {
		// Calculate success rate: (non-5xx requests / total requests) * 100
		baseQuery.Calculations = []Calculation{
			{Op: "COUNT"},
		}
		baseQuery.Filters = append(baseQuery.Filters, Filter{
			Column: "http.status_code",
			Op:     "<",
			Value:  500,
		})
		return baseQuery, nil
	}

	// Latency query pattern - query actual trace spans with duration_ms
	if strings.Contains(promQL, "histogram_quantile") || strings.Contains(promQL, "duration") {
		// Query individual trace spans for P95 duration (like Dynatrace)
		baseQuery.Calculations = []Calculation{
			{Op: "P95", Column: "duration_ms"},
		}
		return baseQuery, nil
	}

	// Request rate query pattern
	if strings.Contains(promQL, "rate") && strings.Contains(promQL, "http_requests_total") {
		baseQuery.Calculations = []Calculation{
			{Op: "COUNT"},
		}
		return baseQuery, nil
	}

	// Throughput/count query
	if strings.Contains(promQL, "http_requests_total") {
		baseQuery.Calculations = []Calculation{
			{Op: "COUNT"},
		}
		return baseQuery, nil
	}

	return nil, fmt.Errorf("unsupported query pattern: %s", promQL)
}

func (h *HoneycombAdapter) extractServiceName(promQL string) string {
	log.Printf("🔍 Extracting service name from PromQL: %s", promQL)
	
	// Pattern 1: service="my-app"
	re1 := regexp.MustCompile(`service="([^"]+)"`)
	if matches := re1.FindStringSubmatch(promQL); len(matches) > 1 {
		serviceName := matches[1]
		log.Printf("📍 Found service name (pattern 1): %s", serviceName)
		// Handle Flagger template variables
		if strings.Contains(serviceName, "{{ args.name }}") {
			// Extract the actual service name from the template
			// This assumes the template has been processed by Flagger
			serviceName = strings.ReplaceAll(serviceName, "{{ args.name }}", "")
			serviceName = strings.Trim(serviceName, " -")
			log.Printf("📍 Processed template service name: %s", serviceName)
		}
		return serviceName
	}

	// Pattern 2: job="my-app"
	re2 := regexp.MustCompile(`job="([^"]+)"`)
	if matches := re2.FindStringSubmatch(promQL); len(matches) > 1 {
		log.Printf("📍 Found service name (pattern 2): %s", matches[1])
		return matches[1]
	}

	// Pattern 3: Direct template variable usage
	re3 := regexp.MustCompile(`\{\{\s*args\.name\s*\}\}`)
	if re3.MatchString(promQL) {
		log.Printf("📍 Found template variable in query")
		// Flagger will replace this with the actual service name
		// For now, we'll return empty and let the query filter handle it
		return ""
	}

	log.Printf("⚠️  No service name found in query: %s", promQL)
	h.logDebug("No service name found in query: %s", promQL)
	return ""
}

func (h *HoneycombAdapter) extractTimeWindow(promQL string) time.Duration {
	// Extract time window from rate() function: rate(metric[5m])
	re := regexp.MustCompile(`\[(\d+)([smhd])\]`)
	matches := re.FindStringSubmatch(promQL)
	
	if len(matches) >= 3 {
		value, err := strconv.Atoi(matches[1])
		if err != nil {
			return 8 * time.Hour // default changed to 8 hours
		}
		
		unit := matches[2]
		switch unit {
		case "s":
			return time.Duration(value) * time.Second
		case "m":
			return time.Duration(value) * time.Minute
		case "h":
			return time.Duration(value) * time.Hour
		case "d":
			return time.Duration(value) * 24 * time.Hour
		}
	}
	
	return 8 * time.Hour // default changed to 8 hours
}

func (h *HoneycombAdapter) executeHoneycombQuery(query *HoneycombQuery, serviceName string) (map[string]interface{}, error) {
	// Use service name as dataset - no need to extract from filters
	dataset := serviceName
	if dataset == "" {
		dataset = "unknown"
	}
	
	// Step 1: Create the query and get the ID
	queryID, err := h.createHoneycombQuery(dataset, query)
	if err != nil {
		return nil, fmt.Errorf("failed to create query: %v", err)
	}
	
	log.Printf("🆔 Created query with ID: %s", queryID)
	
	// Step 2: Execute the query using the ID
	return h.executeHoneycombQueryByID(dataset, queryID)
}

func (h *HoneycombAdapter) createHoneycombQuery(dataset string, query *HoneycombQuery) (string, error) {
	// Use the correct Honeycomb API endpoint: /1/queries/{dataset}
	url := fmt.Sprintf("%s/1/queries/%s", h.honeycombBaseURL, dataset)
	log.Printf("🎯 Using Honeycomb dataset: %s", dataset)

	jsonData, err := json.Marshal(query)
	if err != nil {
		return "", fmt.Errorf("failed to marshal query: %v", err)
	}

	log.Printf("🚀 Creating query in Honeycomb: %s", string(jsonData))
	h.logDebug("Sending to Honeycomb: %s", string(jsonData))

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Honeycomb-Team", h.honeycombAPIKey)
	
	log.Printf("📤 HTTP Request (Create Query):")
	log.Printf("  URL: %s", url)
	log.Printf("  Method: POST")
	log.Printf("  Headers: Content-Type=application/json, X-Honeycomb-Team=%s...", h.honeycombAPIKey[:8])
	log.Printf("  Body: %s", string(jsonData))

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("❌ HTTP request failed: %v", err)
		return "", fmt.Errorf("failed to execute request: %v", err)
	}
	defer resp.Body.Close()
	
	log.Printf("📥 HTTP Response (Create Query):")
	log.Printf("  Status: %d %s", resp.StatusCode, resp.Status)

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		log.Printf("❌ Honeycomb API returned status %d", resp.StatusCode)
		return "", fmt.Errorf("honeycomb API returned status %d", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		log.Printf("❌ Failed to decode response: %v", err)
		return "", fmt.Errorf("failed to decode response: %v", err)
	}

	log.Printf("📊 Query creation response: %+v", result)
	
	// Extract the query ID
	if id, ok := result["id"].(string); ok {
		return id, nil
	}
	
	return "", fmt.Errorf("no query ID returned from Honeycomb")
}

func (h *HoneycombAdapter) executeHoneycombQueryByID(dataset string, queryID string) (map[string]interface{}, error) {
	// Use the query results endpoint: POST /1/query_results/{dataset}
	url := fmt.Sprintf("%s/1/query_results/%s", h.honeycombBaseURL, dataset)
	
	// Create the request body with query_id
	requestBody := map[string]interface{}{
		"query_id":                   queryID,
		"disable_series":             false,
		"disable_total_by_aggregate": true,
		"disable_other_by_aggregate": true,
		"limit":                      10000,
	}
	
	jsonData, err := json.Marshal(requestBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request body: %v", err)
	}
	
	log.Printf("🔍 Executing query by ID:")
	log.Printf("  URL: %s", url)
	log.Printf("  Query ID: %s", queryID)
	log.Printf("  Request body: %s", string(jsonData))

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Honeycomb-Team", h.honeycombAPIKey)
	
	log.Printf("📤 HTTP Request (Execute Query):")
	log.Printf("  URL: %s", url)
	log.Printf("  Method: POST")
	log.Printf("  Headers: Content-Type=application/json, X-Honeycomb-Team=%s...", h.honeycombAPIKey[:8])
	log.Printf("  Body: %s", string(jsonData))

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("❌ HTTP request failed: %v", err)
		return nil, fmt.Errorf("failed to execute request: %v", err)
	}
	defer resp.Body.Close()
	
	log.Printf("📥 HTTP Response (Execute Query):")
	log.Printf("  Status: %d %s", resp.StatusCode, resp.Status)

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		log.Printf("❌ Honeycomb API returned status %d", resp.StatusCode)
		return nil, fmt.Errorf("honeycomb API returned status %d", resp.StatusCode)
	}

	// Check if we got HTTP 201 (Created) with Location header
	if resp.StatusCode == http.StatusCreated {
		location := resp.Header.Get("Location")
		if location != "" {
			log.Printf("🔗 Got HTTP 201 with Location header: %s", location)
			
			// Follow the Location header to get actual results
			return h.getQueryResultsByLocation(dataset, location)
		}
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		log.Printf("❌ Failed to decode response: %v", err)
		return nil, fmt.Errorf("failed to decode response: %v", err)
	}

	log.Printf("📊 Query execution results: %+v", result)
	return result, nil
}

func (h *HoneycombAdapter) getQueryResultsByLocation(dataset string, location string) (map[string]interface{}, error) {
	// The location header gives us the path, we need to construct the full URL
	fullURL := fmt.Sprintf("%s%s", h.honeycombBaseURL, location)
	
	log.Printf("🔗 Following Location header to get actual results:")
	log.Printf("  URL: %s", fullURL)

	req, err := http.NewRequest("GET", fullURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request for location: %v", err)
	}

	req.Header.Set("X-Honeycomb-Team", h.honeycombAPIKey)
	
	log.Printf("📤 HTTP Request (Get Results by Location):")
	log.Printf("  URL: %s", fullURL)
	log.Printf("  Method: GET")
	log.Printf("  Headers: X-Honeycomb-Team=%s...", h.honeycombAPIKey[:8])

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("❌ HTTP request failed: %v", err)
		return nil, fmt.Errorf("failed to execute location request: %v", err)
	}
	defer resp.Body.Close()
	
	log.Printf("📥 HTTP Response (Get Results by Location):")
	log.Printf("  Status: %d %s", resp.StatusCode, resp.Status)

	if resp.StatusCode != http.StatusOK {
		log.Printf("❌ Honeycomb API returned status %d for location", resp.StatusCode)
		return nil, fmt.Errorf("honeycomb API returned status %d for location", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		log.Printf("❌ Failed to decode location response: %v", err)
		return nil, fmt.Errorf("failed to decode location response: %v", err)
	}

	log.Printf("📊 Actual query results from location: %+v", result)
	return result, nil
}

func (h *HoneycombAdapter) convertToPrometheusFormat(honeycombResult map[string]interface{}, timeParam string) *PrometheusResponse {
	value := h.extractValueFromHoneycombResult(honeycombResult)

	// Convert to Unix timestamp
	timestamp := time.Now().Unix()
	if timeParam != "" {
		if t, err := time.Parse(time.RFC3339, timeParam); err == nil {
			timestamp = t.Unix()
		}
	}

	return &PrometheusResponse{
		Status: "success",
		Data: struct {
			ResultType string `json:"resultType"`
			Result     []struct {
				Metric map[string]string `json:"metric"`
				Value  []interface{}     `json:"value"`
			} `json:"result"`
		}{
			ResultType: "vector",
			Result: []struct {
				Metric map[string]string `json:"metric"`
				Value  []interface{}     `json:"value"`
			}{
				{
					Metric: map[string]string{},
					Value:  []interface{}{timestamp, fmt.Sprintf("%.2f", value)},
				},
			},
		},
	}
}

func (h *HoneycombAdapter) extractValueFromHoneycombResult(result map[string]interface{}) float64 {
	log.Printf("🔍 Extracting value from Honeycomb result structure...")
	
	// Navigate Honeycomb's JSON structure to extract the numeric result
	if data, ok := result["data"].(map[string]interface{}); ok {
		log.Printf("📊 Found data field in result")
		
		// Try the results array first (this is where the total COUNT is)
		if results, ok := data["results"].([]interface{}); ok && len(results) > 0 {
			log.Printf("📊 Found results array with %d items", len(results))
			
			if firstResult, ok := results[0].(map[string]interface{}); ok {
				if dataPoint, ok := firstResult["data"].(map[string]interface{}); ok {
					log.Printf("📊 Found data point: %+v", dataPoint)
					
					// Look for calculated values (COUNT, P95, AVG, etc.)
					for key, v := range dataPoint {
						if strings.Contains(strings.ToUpper(key), "COUNT") || 
						   strings.Contains(strings.ToUpper(key), "AVG") ||
						   strings.Contains(strings.ToUpper(key), "P95") ||
						   strings.Contains(strings.ToUpper(key), "DURATION_MS") {
							if val, ok := v.(float64); ok {
								log.Printf("✅ Extracted value %f from field %s", val, key)
								h.logDebug("Extracted value %f from field %s", val, key)
								return val
							}
						}
					}
					
					// Fallback: try any numeric value
					for key, v := range dataPoint {
						if val, ok := v.(float64); ok {
							log.Printf("✅ Extracted fallback value %f from field %s", val, key)
							h.logDebug("Extracted fallback value: %f", val)
							return val
						}
					}
				}
			}
		}
		
		// Fallback: try the old structure for backward compatibility
		if results, ok := data["results"].([]interface{}); ok && len(results) > 0 {
			if firstResult, ok := results[0].(map[string]interface{}); ok {
				if dataPoints, ok := firstResult["data"].([]interface{}); ok && len(dataPoints) > 0 {
					if point, ok := dataPoints[0].(map[string]interface{}); ok {
						// Look for calculated values (COUNT, P95, AVG, etc.)
						for key, v := range point {
							if strings.Contains(strings.ToLower(key), "count") || 
							   strings.Contains(strings.ToLower(key), "avg") ||
							   strings.Contains(strings.ToLower(key), "p95") ||
							   strings.Contains(strings.ToLower(key), "duration_ms") {
								if val, ok := v.(float64); ok {
									log.Printf("✅ Extracted value %f from field %s (old structure)", val, key)
									h.logDebug("Extracted value %f from field %s", val, key)
									return val
								}
							}
						}
					}
				}
			}
		}
	}

	log.Printf("❌ No numeric value found in Honeycomb result, returning 0")
	h.logDebug("No numeric value found in Honeycomb result, returning 0")
	return 0.0
}

func (h *HoneycombAdapter) logDebug(format string, args ...interface{}) {
	if h.logLevel == "debug" {
		log.Printf("[DEBUG] "+format, args...)
	}
}

func (h *HoneycombAdapter) logError(format string, args ...interface{}) {
	log.Printf("[ERROR] "+format, args...)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}