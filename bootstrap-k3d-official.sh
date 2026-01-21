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

# 5. Import Images (Only needed for local dev images if we were building them)
# For official quickstart, we pull from OCI, so no local build needed.
# However, we still need our custom MCP server image.
echo "� Importing MCP Server image..."
k3d image import -c $CLUSTER_NAME twenty-crm-mcp-server:latest


# 7. Install Helm Charts (Official Quickstart)

echo "🚀 Installing Gateway API CRDs..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml

echo "🚀 Deploying KGateway CRDs..."
helm upgrade -i kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds \
    --create-namespace \
    --namespace kgateway-system \
    --version v2.1.2

echo "🚀 Deploying KGatewayControl Plane (AgentGateway Enabled)..."
helm upgrade -i kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway \
    --namespace kgateway-system \
    --version v2.1.2 \
    --set agentgateway.enabled=true \
    --set controller.image.pullPolicy=Always

echo "🚀 Deploying AgentGateway UI (Community Image)..."
# Using the UI image we found earlier on Docker Hub / GitHub Packages
kubectl create deployment agentgateway-ui --image=agentgateway/agentgateway-ui:latest -n kgateway-system --dry-run=client -o yaml | kubectl apply -f -
kubectl expose deployment agentgateway-ui --port=80 --target-port=80 --name=agentgateway-ui -n kgateway-system --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Deployment Complete!"
echo "Cluster: $CLUSTER_NAME"
echo "API Ports: 8080 (HTTP), 8443 (HTTPS)"
echo ""
echo "Verify execution:"
echo "  kubectl get pods -n kgateway-system"
