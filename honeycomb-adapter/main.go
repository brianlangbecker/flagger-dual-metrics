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
	TimeRange    TimeRange     `json:"time_range"`
	Granularity  int          `json:"granularity,omitempty"`
	Calculations []Calculation `json:"calculations"`
	Filters      []Filter     `json:"filters,omitempty"`
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

type TimeRange struct {
	StartTime int64 `json:"start_time"`
	EndTime   int64 `json:"end_time"`
}

func main() {
	adapter := &HoneycombAdapter{
		honeycombAPIKey:  getEnv("HONEYCOMB_API_KEY", ""),
		honeycombDataset: getEnv("HONEYCOMB_DATASET", "podinfo-service"),
		honeycombBaseURL: getEnv("HONEYCOMB_BASE_URL", "https://api.honeycomb.io"),
		logLevel:         getEnv("LOG_LEVEL", "info"),
	}

	if adapter.honeycombAPIKey == "" {
		log.Fatal("HONEYCOMB_API_KEY environment variable is required")
	}

	http.HandleFunc("/api/v1/query", adapter.handleQuery)
	http.HandleFunc("/api/v1/query_range", adapter.handleQueryRange)
	http.HandleFunc("/-/healthy", adapter.handleHealth)
	http.HandleFunc("/-/ready", adapter.handleReady)

	port := getEnv("PORT", "9090")
	log.Printf("Starting Honeycomb-Prometheus adapter on port %s", port)
	log.Printf("Dataset: %s, Base URL: %s", adapter.honeycombDataset, adapter.honeycombBaseURL)
	
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func (h *HoneycombAdapter) handleQuery(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("query")
	timeParam := r.URL.Query().Get("time")

	h.logDebug("Received query: %s", query)

	if query == "" {
		http.Error(w, "query parameter is required", http.StatusBadRequest)
		return
	}

	// Parse the PromQL query and convert to Honeycomb query
	honeycombQuery, err := h.translatePromQLToHoneycomb(query)
	if err != nil {
		h.logError("Query translation error: %v", err)
		http.Error(w, fmt.Sprintf("Query translation error: %v", err), http.StatusBadRequest)
		return
	}

	h.logDebug("Translated to Honeycomb query: %+v", honeycombQuery)

	// Execute Honeycomb query
	result, err := h.executeHoneycombQuery(honeycombQuery)
	if err != nil {
		h.logError("Honeycomb query error: %v", err)
		http.Error(w, fmt.Sprintf("Honeycomb query error: %v", err), http.StatusInternalServerError)
		return
	}

	h.logDebug("Honeycomb result: %+v", result)

	// Convert Honeycomb result to Prometheus format
	promResponse := h.convertToPrometheusFormat(result, timeParam)

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(promResponse); err != nil {
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
		TimeRange: TimeRange{
			StartTime: time.Now().Add(-1 * time.Minute).Unix(),
			EndTime:   time.Now().Unix(),
		},
		Calculations: []Calculation{{Op: "COUNT"}},
	}

	_, err := h.executeHoneycombQuery(testQuery)
	if err != nil {
		h.logError("Readiness check failed: %v", err)
		http.Error(w, "Not ready", http.StatusServiceUnavailable)
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Ready"))
}

func (h *HoneycombAdapter) translatePromQLToHoneycomb(promQL string) (*HoneycombQuery, error) {
	serviceName := h.extractServiceName(promQL)
	timeWindow := h.extractTimeWindow(promQL)

	startTime := time.Now().Add(-timeWindow).Unix()
	endTime := time.Now().Unix()

	baseQuery := &HoneycombQuery{
		TimeRange: TimeRange{
			StartTime: startTime,
			EndTime:   endTime,
		},
		Filters: []Filter{},
	}

	// Add service filter if found
	if serviceName != "" {
		baseQuery.Filters = append(baseQuery.Filters, Filter{
			Column: "service.name",
			Op:     "=",
			Value:  serviceName,
		})
	}

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
	// Pattern 1: service="my-app"
	re1 := regexp.MustCompile(`service="([^"]+)"`)
	if matches := re1.FindStringSubmatch(promQL); len(matches) > 1 {
		return matches[1]
	}

	// Pattern 2: job="my-app"
	re2 := regexp.MustCompile(`job="([^"]+)"`)
	if matches := re2.FindStringSubmatch(promQL); len(matches) > 1 {
		return matches[1]
	}

	// Pattern 3: Flagger template variable
	re3 := regexp.MustCompile(`\{\{\s*args\.name\s*\}\}`)
	if re3.MatchString(promQL) {
		return "{{ args.name }}" // Will be replaced by Flagger
	}

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
			return 5 * time.Minute // default
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
	
	return 5 * time.Minute // default
}

func (h *HoneycombAdapter) executeHoneycombQuery(query *HoneycombQuery) (map[string]interface{}, error) {
	url := fmt.Sprintf("%s/1/query/%s", h.honeycombBaseURL, h.honeycombDataset)

	jsonData, err := json.Marshal(query)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal query: %v", err)
	}

	h.logDebug("Sending to Honeycomb: %s", string(jsonData))

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Honeycomb-Team", h.honeycombAPIKey)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("honeycomb API returned status %d", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %v", err)
	}

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
	// Navigate Honeycomb's JSON structure to extract the numeric result
	if data, ok := result["data"].(map[string]interface{}); ok {
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
									h.logDebug("Extracted value %f from field %s", val, key)
									return val
								}
							}
						}
						
						// Fallback: try any numeric value
						for _, v := range point {
							if val, ok := v.(float64); ok {
								h.logDebug("Extracted fallback value: %f", val)
								return val
							}
						}
					}
				}
			}
		}
	}

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