FROM python:3.9-slim

WORKDIR /app

# Install required packages
RUN pip install flask opentelemetry-api opentelemetry-sdk \
    opentelemetry-exporter-otlp-proto-http \
    opentelemetry-instrumentation-flask \
    opentelemetry-instrumentation-requests

# Copy the app
COPY simple-otel-app.py /app/

# Expose port
EXPOSE 8080

# Run the app
CMD ["python", "simple-otel-app.py"]