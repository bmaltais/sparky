#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTRY_IP="100.101.186.51"
REGISTRY_PORT=5000
REGISTRY_URL="${REGISTRY_IP}:${REGISTRY_PORT}"

echo "=== Deploying Container Registry ==="
echo "Registry URL: http://${REGISTRY_URL}"
echo "(No auth — open registry, like the local docker one)"

# 1. Create namespace
echo "[1/3] Creating namespace..."
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

# 2. Create PVC
echo "[2/3] Creating persistent volume..."
kubectl apply -f "${SCRIPT_DIR}/pvc.yaml"

# 3. Deploy registry
echo "[3/3] Deploying registry..."
kubectl apply -f "${SCRIPT_DIR}/deployment.yaml"

# Wait for readiness
kubectl rollout status deployment/registry -n docker-registry --timeout=120s

echo ""
echo "=== Registry Deployed ==="
echo ""
echo "Access from Tailscale: http://${REGISTRY_URL}"
echo "No login required — push/pull directly."
echo ""
echo "Next steps:"
echo "  1. Configure k3s registries.yaml on all nodes (see /etc/rancher/k3s/registries.yaml)"
echo "  2. Run: docker push ${REGISTRY_URL}/your-image:tag"
echo "  3. Use in deployments: ${REGISTRY_URL}/your-image:tag"
echo ""
echo "Configure k3s nodes: bash ${SCRIPT_DIR}/configure-k3s.sh"
