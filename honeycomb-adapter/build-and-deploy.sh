#!/bin/bash
set -e

NAMESPACE="flagger-system"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔨 Building and deploying honeycomb-adapter in-cluster..."

# Ensure namespace exists
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create ConfigMap with source code
echo "📦 Creating source code ConfigMap..."
kubectl create configmap honeycomb-adapter-source \
  --from-file=main.go=main.go \
  --from-file=go.mod=go.mod \
  --from-file=go.sum=go.sum \
  --from-file=Dockerfile=Dockerfile \
  --namespace=$NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

# Apply RBAC and Job
echo "🚀 Starting build job..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: honeycomb-adapter-builder
  namespace: $NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: honeycomb-adapter-builder
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "patch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: honeycomb-adapter-builder
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: honeycomb-adapter-builder
subjects:
- kind: ServiceAccount
  name: honeycomb-adapter-builder
  namespace: $NAMESPACE
---
apiVersion: batch/v1
kind: Job
metadata:
  name: honeycomb-adapter-builder-$(date +%s)
  namespace: $NAMESPACE
  labels:
    app: honeycomb-adapter-builder
spec:
  backoffLimit: 2
  template:
    metadata:
      labels:
        app: honeycomb-adapter-builder
    spec:
      restartPolicy: Never
      serviceAccountName: honeycomb-adapter-builder
      volumes:
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
      - name: source-code
        configMap:
          name: honeycomb-adapter-source
      containers:
      - name: builder
        image: docker:24-dind
        command:
        - /bin/sh
        - -c
        - |
          set -e
          echo "🔨 Starting Docker build process..."
          
          # Start Docker daemon
          dockerd-entrypoint.sh &
          DOCKER_PID=\$!
          
          # Wait for Docker to be ready
          echo "⏳ Waiting for Docker daemon..."
          until docker info >/dev/null 2>&1; do
            sleep 1
          done
          echo "✅ Docker daemon ready"
          
          # Create build directory
          mkdir -p /build
          cd /build
          
          # Copy source files from ConfigMap
          cp /source/* .
          ls -la
          
          # Build Docker image
          echo "🏗️ Building honeycomb-adapter Docker image..."
          docker build -t honeycomb-adapter:latest .
          
          echo "✅ Build completed successfully!"
          docker images | grep honeycomb-adapter
          
          # Clean up Docker daemon
          kill \$DOCKER_PID 2>/dev/null || true
        volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock
        - name: source-code
          mountPath: /source
        env:
        - name: DOCKER_TLS_CERTDIR
          value: ""
        securityContext:
          privileged: true
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2
            memory: 4Gi
EOF

# Wait for build to complete
echo "⏳ Waiting for build to complete..."
BUILD_JOB=$(kubectl get jobs -n $NAMESPACE -l app=honeycomb-adapter-builder --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')

if [ -z "$BUILD_JOB" ]; then
  echo "❌ Failed to find build job"
  exit 1
fi

echo "📋 Watching build job: $BUILD_JOB"

# Follow build logs
kubectl logs -n $NAMESPACE job/$BUILD_JOB -f &
LOG_PID=$!

# Wait for job completion
kubectl wait --for=condition=complete --timeout=600s job/$BUILD_JOB -n $NAMESPACE

# Stop log following
kill $LOG_PID 2>/dev/null || true

# Check if build succeeded
if kubectl get job $BUILD_JOB -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' | grep -q "True"; then
  echo "✅ Build completed successfully!"
else
  echo "❌ Build failed!"
  kubectl logs -n $NAMESPACE job/$BUILD_JOB --tail=50
  exit 1
fi

# Deploy the adapter
echo "🚀 Deploying honeycomb-adapter..."
kubectl apply -f deployment/

# Wait for deployment to be ready
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/honeycomb-adapter -n $NAMESPACE

echo "✅ honeycomb-adapter deployed successfully!"

# Show status
echo "📊 Deployment status:"
kubectl get pods -n $NAMESPACE -l app=honeycomb-adapter
kubectl get svc -n $NAMESPACE -l app=honeycomb-adapter

# Clean up build job
echo "🧹 Cleaning up build job..."
kubectl delete job $BUILD_JOB -n $NAMESPACE

echo ""
echo "🎉 honeycomb-adapter is ready!"
echo ""
echo "To test the adapter:"
echo "  kubectl port-forward -n $NAMESPACE svc/honeycomb-adapter 9090:9090"
echo "  curl http://localhost:9090/-/healthy"
echo ""
echo "To view logs:"
echo "  kubectl logs -n $NAMESPACE -l app=honeycomb-adapter -f"