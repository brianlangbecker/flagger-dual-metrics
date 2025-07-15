#!/usr/bin/env python3
from flask import Flask, jsonify, request
import time
import random
import os
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Configure OpenTelemetry
resource = Resource.create({
    "service.name": "podinfo",
    "service.version": "1.0.0",
})

trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)

# Configure OTLP exporter to send to collector
otlp_exporter = OTLPSpanExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector.flagger-system:4318/v1/traces"),
    headers={}
)

span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Create Flask app
app = Flask(__name__)

# Auto-instrument Flask
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()

@app.route('/version')
def version():
    with tracer.start_as_current_span("get_version") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.target", "/version")
        span.set_attribute("http.status_code", 200)
        
        # Simulate some work
        time.sleep(random.uniform(0.01, 0.05))
        
        return jsonify({
            "version": "6.0.0",
            "commit": "abc123"
        })

@app.route('/healthz')
def healthz():
    with tracer.start_as_current_span("health_check") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.target", "/healthz")
        span.set_attribute("http.status_code", 200)
        
        # Simulate some work
        time.sleep(random.uniform(0.005, 0.02))
        
        return jsonify({"status": "OK"})

@app.route('/delay/<float:seconds>')
def delay(seconds):
    with tracer.start_as_current_span("delay_endpoint") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.target", f"/delay/{seconds}")
        span.set_attribute("delay.seconds", seconds)
        span.set_attribute("http.status_code", 200)
        
        # Actual delay
        time.sleep(seconds)
        
        return jsonify({"delay": seconds})

@app.route('/error/<int:code>')
def error_endpoint(code):
    with tracer.start_as_current_span("error_endpoint") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.target", f"/error/{code}")
        span.set_attribute("http.status_code", code)
        span.set_attribute("error", True)
        
        # Simulate error processing time
        time.sleep(random.uniform(0.1, 0.5))
        
        return jsonify({"error": f"HTTP {code}"}), code

@app.route('/load')
def load_test():
    with tracer.start_as_current_span("load_test") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.target", "/load")
        span.set_attribute("http.status_code", 200)
        
        # Simulate heavy load
        work_time = random.uniform(0.1, 1.0)
        time.sleep(work_time)
        
        span.set_attribute("work.duration_ms", work_time * 1000)
        
        return jsonify({
            "message": "Load test completed",
            "work_duration_ms": work_time * 1000
        })

if __name__ == '__main__':
    print("🚀 Starting OpenTelemetry instrumented app")
    print(f"📡 OTLP Endpoint: {os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://otel-collector.flagger-system:4318/v1/traces')}")
    print(f"🔍 Service Name: podinfo")
    print("📋 Available endpoints:")
    print("  GET /version - Get app version")
    print("  GET /healthz - Health check")
    print("  GET /delay/<seconds> - Delay response")
    print("  GET /error/<code> - Return error code")
    print("  GET /load - CPU load test")
    
    app.run(host='0.0.0.0', port=8080, debug=False)