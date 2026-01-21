#!/bin/bash
set -e

CLUSTER_NAME="realboost-cluster"
VERSION="v2.1.2" # Using stable version from Quickstart

echo "🚀 Bootstrapping AgentGateway Environment..."

# 1. Clean up old cluster
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "♻️  Deleting existing k3d cluster '$CLUSTER_NAME'..."
    k3d cluster delete "$CLUSTER_NAME"
fi

# 2. Create Cluster
echo "📦 Creating k3d cluster..."
# Ensure k3d-config.yaml exists or create a temp one
if [ ! -f "k3d-config.yaml" ]; then
    echo "⚠️  k3d-config.yaml not found, using default loadbalancer config."
    # Basic config with exposed 8080/8443
    k3d cluster create "$CLUSTER_NAME" -p "8090:80@loadbalancer" -p "8443:443@loadbalancer"
else
    k3d cluster create --config k3d-config.yaml
fi

# 3. Import Custom Images
# If you have specific local images like the MCP server, import them here.
if docker image inspect twenty-crm-mcp-server:latest >/dev/null 2>&1; then
    echo "📦 Importing custom MCP Server image..."
    k3d image import -c "$CLUSTER_NAME" twenty-crm-mcp-server:latest
else
    echo "⚠️  Custom MCP Server image not found locally, skipping import."
fi

# 4. Install Gateway API CRDs
echo "📄 Installing Gateway API CRDs..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml

# 5. Deploy KGateway with AgentGateway Enabled
echo "🚀 Deploying KGateway CRDs..."
helm upgrade -i kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds \
    --create-namespace \
    --namespace kgateway-system \
    --version "$VERSION"

echo "🚀 Deploying KGateway Control Plane (AgentGateway Enabled)..."
# Extracted from ey-ai-art-cli logic: agentgateway.enabled=true
helm upgrade -i kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway \
    --namespace kgateway-system \
    --version "$VERSION" \
    --set agentgateway.enabled=true \
    --set controller.image.pullPolicy=Always

# 6. Deploy AgentGateway UI
echo "🚀 Deploying AgentGateway UI..."
# Using the community image
kubectl create deployment agentgateway-ui --image=agentgateway/agentgateway-ui:latest -n kgateway-system --dry-run=client -o yaml | kubectl apply -f -
kubectl expose deployment agentgateway-ui --port=80 --target-port=80 --name=agentgateway-ui -n kgateway-system --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Setup Complete!"
echo "Cluster: $CLUSTER_NAME"
echo "Check pods: kubectl get pods -n kgateway-system"
echo "Access AgentGateway UI via kubectl port-forward -n kgateway-system svc/agentgateway-ui 3001:80"
