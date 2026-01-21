#!/bin/bash
set -e

CLUSTER_NAME="realboost-cluster"
VERSION="0.0.0-local"
IMAGE_REGISTRY="ghcr.io/kgateway-dev"

echo "🚀 Bootstrapping RealBoost AgentGateway on K3d..."

# 1. Clean up old cluster
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "♻️  Deleting existing k3d cluster '$CLUSTER_NAME'..."
    k3d cluster delete "$CLUSTER_NAME"
fi

# 2. Create Cluster
echo "📦 Creating k3d cluster..."
k3d cluster create --config k3d-config.yaml

# 3. Install Standard Gateway API CRDs
echo "📄 Installing Gateway API CRDs..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

# 4. Build Docker Images (using the Repo's Makefile)
echo "🏗️  Building AgentGateway Docker images (Version: $VERSION)..."
# We explicitly set GOARCH just in case, though Makefile usually handles it
make kgateway-docker VERSION=$VERSION
make agentgateway-controller-docker VERSION=$VERSION
make envoy-wrapper-docker VERSION=$VERSION

# 5. Import Images into K3d
echo "📥 Importing images into k3d..."
k3d image import -c "$CLUSTER_NAME" \
  "$IMAGE_REGISTRY/kgateway:$VERSION" \
  "$IMAGE_REGISTRY/agentgateway-controller:$VERSION" \
  "$IMAGE_REGISTRY/envoy-wrapper:$VERSION"

# 6. Package Helm Charts
echo "📦 Packaging Helm charts..."
make package-kgateway-charts VERSION=$VERSION
make package-agentgateway-charts VERSION=$VERSION

# 7. Install Helm Charts
echo "🚀 Deploying KGateway CRDs..."
helm upgrade --install kgateway-crds _test/kgateway-crds-$VERSION.tgz \
    --namespace kgateway-system --create-namespace

echo "🚀 Deploying KGateway..."
helm upgrade --install kgateway _test/kgateway-$VERSION.tgz \
    --namespace kgateway-system --create-namespace \
    --set image.registry=$IMAGE_REGISTRY \
    --set image.tag=$VERSION \
    --set image.pullPolicy=Never

echo "🚀 Deploying AgentGateway CRDs..."
helm upgrade --install agentgateway-crds _test/agentgateway-crds-$VERSION.tgz \
    --namespace kgateway-system --create-namespace

echo "🚀 Deploying AgentGateway..."
helm upgrade --install agentgateway _test/agentgateway-$VERSION.tgz \
    --namespace kgateway-system --create-namespace \
    --set image.registry=$IMAGE_REGISTRY \
    --set image.tag=$VERSION \
    --set image.pullPolicy=Never \
    --set controller.image.repository=agentgateway-controller

echo "✅ Deployment Complete!"
echo "Cluster: $CLUSTER_NAME"
echo "API Ports: 8080 (HTTP), 8443 (HTTPS)"
echo ""
echo "Verify execution:"
echo "  kubectl get pods -n kgateway-system"
