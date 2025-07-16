#!/usr/bin/env python3
import requests
import json
import time
import random
from datetime import datetime, timezone

# Honeycomb configuration
import os
API_KEY = os.getenv("HONEYCOMB_API_KEY", "")
DATASET = "podinfo-service"
HONEYCOMB_URL = "https://api.honeycomb.io/1/events"

if not API_KEY:
    print("❌ HONEYCOMB_API_KEY environment variable not set")
    print("Run: export HONEYCOMB_API_KEY=your_api_key")
    exit(1)

def send_trace_event(service_name, endpoint, method, status_code, duration_ms):
    """Send a trace event to Honeycomb (like what an instrumented app would send)"""
    
    event_data = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service.name": service_name,
        "http.method": method,
        "http.target": endpoint,
        "http.status_code": status_code,
        "duration_ms": duration_ms,
        "span.kind": "server",
        "trace.trace_id": f"trace-{random.randint(100000, 999999)}",
        "trace.span_id": f"span-{random.randint(100000, 999999)}",
        "error": status_code >= 400
    }
    
    headers = {
        "X-Honeycomb-Team": API_KEY,
        "Content-Type": "application/json"
    }
    
    url = f"{HONEYCOMB_URL}/{DATASET}"
    
    try:
        response = requests.post(url, json=event_data, headers=headers)
        if response.status_code == 200:
            print(f"✅ Sent: {method} {endpoint} - {status_code} - {duration_ms}ms")
        else:
            print(f"❌ Failed: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ Error: {e}")

def generate_realistic_traffic():
    """Generate realistic HTTP traffic data"""
    
    endpoints = [
        ("/version", "GET", [200]),
        ("/healthz", "GET", [200]),
        ("/delay/0.1", "GET", [200]),
        ("/delay/0.5", "GET", [200]),
        ("/api/info", "GET", [200, 404]),
        ("/api/echo", "POST", [200, 400]),
    ]
    
    print("🚀 Generating realistic traffic data for Honeycomb...")
    print(f"📊 Dataset: {DATASET}")
    print(f"🔑 Using API key: {API_KEY[:20]}...")
    print()
    
    for i in range(100):
        endpoint, method, possible_status = random.choice(endpoints)
        status_code = random.choice(possible_status)
        
        # Generate realistic duration based on endpoint
        if "delay" in endpoint:
            base_duration = float(endpoint.split("/")[-1]) * 1000  # Convert to ms
            duration_ms = base_duration + random.uniform(-50, 100)
        else:
            duration_ms = random.uniform(5, 200)  # Normal response times
        
        # Add some error cases
        if random.random() < 0.05:  # 5% error rate
            status_code = random.choice([400, 500, 503])
            duration_ms = random.uniform(1000, 5000)  # Slower error responses
        
        send_trace_event("podinfo", endpoint, method, status_code, duration_ms)
        time.sleep(0.1)  # Small delay between requests
    
    print()
    print("✨ Data generation complete!")
    print(f"🔍 Check your Honeycomb dashboard: {DATASET}")
    print("📈 You should see:")
    print("  - service.name: podinfo")
    print("  - http.status_code: 200, 400, 500, etc.")
    print("  - duration_ms: Individual request durations")
    print("  - Various endpoints and methods")

if __name__ == "__main__":
    generate_realistic_traffic()