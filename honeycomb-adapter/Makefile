.PHONY: build test docker-build docker-push deploy clean help

# Variables
BINARY_NAME=honeycomb-adapter
DOCKER_IMAGE=honeycomb-adapter
DOCKER_TAG=latest
NAMESPACE=flagger-system

# Build the binary
build:
	@echo "Building $(BINARY_NAME)..."
	CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o $(BINARY_NAME) .

# Run tests
test:
	@echo "Running tests..."
	go test -v ./...

# Build Docker image
docker-build:
	@echo "Building Docker image $(DOCKER_IMAGE):$(DOCKER_TAG)..."
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

# Push Docker image
docker-push: docker-build
	@echo "Pushing Docker image $(DOCKER_IMAGE):$(DOCKER_TAG)..."
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)

# Deploy to Kubernetes (assumes image already built)
deploy:
	@echo "Deploying to Kubernetes..."
	kubectl apply -f deployment/

# Build and deploy in-cluster (recommended)
build-and-deploy:
	@echo "Building and deploying in-cluster..."
	./build-and-deploy.sh

# Create secret (interactive)
create-secret:
	@echo "Creating Honeycomb secret..."
	@read -p "Enter your Honeycomb API key: " api_key; \
	kubectl create secret generic honeycomb-secret \
		--from-literal=api-key=$$api_key \
		--namespace=$(NAMESPACE) \
		--dry-run=client -o yaml | kubectl apply -f -

# Deploy examples
deploy-examples:
	@echo "Deploying example configurations..."
	kubectl apply -f examples/

# Port forward for local testing
port-forward:
	@echo "Port forwarding adapter service to localhost:9090..."
	kubectl port-forward -n $(NAMESPACE) svc/honeycomb-adapter 9090:9090

# View logs
logs:
	@echo "Showing adapter logs..."
	kubectl logs -n $(NAMESPACE) -l app=honeycomb-adapter -f

# Check health
health-check:
	@echo "Checking adapter health..."
	curl -f http://localhost:9090/-/healthy || echo "Health check failed"
	curl -f http://localhost:9090/-/ready || echo "Ready check failed"

# Test queries
test-queries:
	@echo "Testing sample queries..."
	@echo "Error rate query:"
	curl -s "http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{code!~\"5.*\",service=\"test\"}[5m]))/sum(rate(http_requests_total{service=\"test\"}[5m]))*100" | jq .
	@echo "Latency query:"
	curl -s "http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,sum(rate(http_request_duration_seconds_bucket{service=\"test\"}[5m])))" | jq .

# Clean up deployment
clean:
	@echo "Cleaning up deployment..."
	kubectl delete -f deployment/ --ignore-not-found
	kubectl delete -f examples/ --ignore-not-found

# Run locally for development
run-local:
	@echo "Running locally (set HONEYCOMB_API_KEY environment variable)..."
	@if [ -z "$(HONEYCOMB_API_KEY)" ]; then \
		echo "Error: HONEYCOMB_API_KEY environment variable not set"; \
		exit 1; \
	fi
	LOG_LEVEL=debug PORT=9090 ./$(BINARY_NAME)

# Install OpenTelemetry Operator (prerequisite)
install-otel-operator:
	@echo "Installing OpenTelemetry Operator..."
	kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

# Show help
help:
	@echo "Available targets:"
	@echo "  build              - Build the Go binary"
	@echo "  test               - Run tests"
	@echo "  docker-build       - Build Docker image"
	@echo "  docker-push        - Build and push Docker image"
	@echo "  build-and-deploy   - Build and deploy in-cluster (recommended)"
	@echo "  deploy             - Deploy to Kubernetes (assumes image already built)"
	@echo "  create-secret      - Create Honeycomb API key secret"
	@echo "  deploy-examples    - Deploy example configurations"
	@echo "  port-forward       - Port forward service for local testing"
	@echo "  logs               - Show adapter logs"
	@echo "  health-check       - Check adapter health"
	@echo "  test-queries       - Test sample queries"
	@echo "  run-local          - Run locally for development"
	@echo "  install-otel-operator - Install OpenTelemetry Operator"
	@echo "  clean              - Clean up deployment"
	@echo "  help               - Show this help"