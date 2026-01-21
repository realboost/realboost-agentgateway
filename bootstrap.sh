#!/bin/bash
set -e

# RealBoost AgentGateway Bootstrap Script
# This script bootstraps the Solo.io kgateway project with AgentGateway enabled.

echo "🚀 Bootstrapping RealBoost AgentGateway..."

# Check dependencies
if ! command -v kind &> /dev/null; then
    echo "❌ 'kind' (Kubernetes in Docker) is not installed."
    echo "Please install kind to run this project locally: https://kind.sigs.k8s.io/"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "❌ 'docker' is not installed."
    echo "Please install Docker to proceed."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ 'kubectl' is not installed."
    echo "Please install kubectl to proceed."
    exit 1
fi

# Run the KGateway/AgentGateway setup via Make
echo "🔧 Setting up local development environment (this may take a few minutes)..."
# Using 'make run-agentgateway' which sets up kind, installs CRDs, and deploys the controller
make run-agentgateway

echo "✅ Environment setup complete."

# Apply RealBoost configurations
echo "📄 Applying RealBoost A2A and MCP configurations..."
kubectl apply -f examples/realboost-samples/mcp-server.yaml
kubectl apply -f examples/realboost-samples/a2a-agent.yaml

echo "🎉 Operations Complete!"
echo "You can now verify the deployment with:"
echo "  kubectl get pods -n kgateway-system"
echo "  kubectl get agentgatewaybackends -n kgateway-system"
