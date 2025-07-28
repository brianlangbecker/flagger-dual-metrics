package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestExtractServiceName(t *testing.T) {
	adapter := &HoneycombAdapter{
		queryTimeWindow: 3 * time.Minute,
	}

	tests := []struct {
		name     string
		promQL   string
		expected string
	}{
		{
			name:     "service label",
			promQL:   `sum(rate(http_requests_total{service="my-app"}[5m]))`,
			expected: "my-app",
		},
		{
			name:     "job label",
			promQL:   `sum(rate(http_requests_total{job="my-service"}[5m]))`,
			expected: "my-service",
		},
		{
			name:     "flagger template variable",
			promQL:   `sum(rate(http_requests_total{service="{{ args.name }}"}[5m]))`,
			expected: "",
		},
		{
			name:     "no service name",
			promQL:   `sum(rate(http_requests_total[5m]))`,
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := adapter.extractServiceName(tt.promQL)
			if result != tt.expected {
				t.Errorf("expected %s, got %s", tt.expected, result)
			}
		})
	}
}

func TestExtractTimeWindow(t *testing.T) {
	adapter := &HoneycombAdapter{
		queryTimeWindow: 3 * time.Minute,
	}

	tests := []struct {
		name     string
		promQL   string
		expected time.Duration
	}{
		{
			name:     "5 minutes",
			promQL:   `sum(rate(http_requests_total[5m]))`,
			expected: 5 * time.Minute,
		},
		{
			name:     "30 seconds",
			promQL:   `sum(rate(http_requests_total[30s]))`,
			expected: 3 * time.Minute, // enforced minimum
		},
		{
			name:     "1 hour",
			promQL:   `sum(rate(http_requests_total[1h]))`,
			expected: 1 * time.Hour,
		},
		{
			name:     "no time window",
			promQL:   `sum(http_requests_total)`,
			expected: 3 * time.Minute, // default from configuration
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := adapter.extractTimeWindow(tt.promQL)
			if result != tt.expected {
				t.Errorf("expected %v, got %v", tt.expected, result)
			}
		})
	}
}

func TestTranslatePromQLToHoneycomb(t *testing.T) {
	adapter := &HoneycombAdapter{
		queryTimeWindow: 3 * time.Minute,
	}

	tests := []struct {
		name     string
		promQL   string
		wantErr  bool
		checkOp  string
	}{
		{
			name:    "error rate query",
			promQL:  `sum(rate(http_requests_total{code!~"5.*",service="test"}[5m]))/sum(rate(http_requests_total{service="test"}[5m]))*100`,
			wantErr: false,
			checkOp: "COUNT",
		},
		{
			name:    "latency query",
			promQL:  `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{service="test"}[5m])))`,
			wantErr: false,
			checkOp: "P95",
		},
		{
			name:    "request rate query",
			promQL:  `sum(rate(http_requests_total{service="test"}[5m]))`,
			wantErr: false,
			checkOp: "COUNT",
		},
		{
			name:    "unsupported query",
			promQL:  `some_unsupported_metric`,
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := adapter.translatePromQLToHoneycomb(tt.promQL)
			
			if tt.wantErr {
				if err == nil {
					t.Errorf("expected error, got nil")
				}
				return
			}

			if err != nil {
				t.Errorf("unexpected error: %v", err)
				return
			}

			if len(result.Calculations) == 0 {
				t.Error("expected calculations, got none")
				return
			}

			if result.Calculations[0].Op != tt.checkOp {
				t.Errorf("expected operation %s, got %s", tt.checkOp, result.Calculations[0].Op)
			}
		})
	}
}

func TestHealthEndpoint(t *testing.T) {
	adapter := &HoneycombAdapter{
		honeycombAPIKey: "test-key",
		logLevel:        "info",
		queryTimeWindow: 3 * time.Minute,
	}

	req, err := http.NewRequest("GET", "/-/healthy", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(adapter.handleHealth)

	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, status)
	}

	expected := "OK"
	if rr.Body.String() != expected {
		t.Errorf("expected body %s, got %s", expected, rr.Body.String())
	}
}

func TestConvertToPrometheusFormat(t *testing.T) {
	adapter := &HoneycombAdapter{
		queryTimeWindow: 3 * time.Minute,
	}

	// Mock Honeycomb response
	honeycombResult := map[string]interface{}{
		"data": map[string]interface{}{
			"results": []interface{}{
				map[string]interface{}{
					"data": []interface{}{
						map[string]interface{}{
							"count": 42.0,
						},
					},
				},
			},
		},
	}

	result := adapter.convertToPrometheusFormat(honeycombResult, "")

	if result.Status != "success" {
		t.Errorf("expected status 'success', got %s", result.Status)
	}

	if result.Data.ResultType != "vector" {
		t.Errorf("expected result type 'vector', got %s", result.Data.ResultType)
	}

	if len(result.Data.Result) != 1 {
		t.Errorf("expected 1 result, got %d", len(result.Data.Result))
	}

	if len(result.Data.Result[0].Value) != 2 {
		t.Errorf("expected 2 values (timestamp, value), got %d", len(result.Data.Result[0].Value))
	}
}

func TestExtractValueFromHoneycombResult(t *testing.T) {
	adapter := &HoneycombAdapter{
		logLevel:        "debug",
		queryTimeWindow: 3 * time.Minute,
	}

	tests := []struct {
		name     string
		input    map[string]interface{}
		expected float64
	}{
		{
			name: "valid count result",
			input: map[string]interface{}{
				"data": map[string]interface{}{
					"results": []interface{}{
						map[string]interface{}{
							"data": []interface{}{
								map[string]interface{}{
									"count": 42.0,
								},
							},
						},
					},
				},
			},
			expected: 42.0,
		},
		{
			name: "valid avg result",
			input: map[string]interface{}{
				"data": map[string]interface{}{
					"results": []interface{}{
						map[string]interface{}{
							"data": []interface{}{
								map[string]interface{}{
									"avg": 123.45,
								},
							},
						},
					},
				},
			},
			expected: 123.45,
		},
		{
			name:     "empty result",
			input:    map[string]interface{}{},
			expected: 0.0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := adapter.extractValueFromHoneycombResult(tt.input)
			if result != tt.expected {
				t.Errorf("expected %f, got %f", tt.expected, result)
			}
		})
	}
}

// Mock Honeycomb server for integration testing
func mockHoneycombServer() *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Handle query creation
		if r.URL.Path == "/1/queries/test" && r.Method == "POST" {
			response := map[string]interface{}{
				"id": "test-query-id",
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(response)
			return
		}
		// Handle query execution
		if r.URL.Path == "/1/query_results/test" && r.Method == "POST" {
			response := map[string]interface{}{
				"data": map[string]interface{}{
					"results": []interface{}{
						map[string]interface{}{
							"data": map[string]interface{}{
								"COUNT": 95.5,
							},
						},
					},
				},
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(response)
			return
		}
		http.NotFound(w, r)
	}))
}

func TestQueryIntegration(t *testing.T) {
	// Start mock Honeycomb server
	mockServer := mockHoneycombServer()
	defer mockServer.Close()

	adapter := &HoneycombAdapter{
		honeycombAPIKey:  "test-key",
		honeycombDataset: "test-dataset",
		honeycombBaseURL: mockServer.URL,
		logLevel:         "debug",
		queryTimeWindow:  3 * time.Minute,
	}

	// Create test server
	testServer := httptest.NewServer(http.HandlerFunc(adapter.handleQuery))
	defer testServer.Close()

	// Test query
	resp, err := http.Get(testServer.URL + "/api/v1/query?query=sum(rate(http_requests_total{code!~\"5.*\",service=\"test\"}[5m]))")
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, resp.StatusCode)
	}

	var result PrometheusResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatal(err)
	}

	if result.Status != "success" {
		t.Errorf("expected status 'success', got %s", result.Status)
	}
}