#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTRY_IP="100.101.186.51"
REGISTRY_PORT=5000
REGISTRY_URL="${REGISTRY_IP}:${REGISTRY_PORT}"
REGISTRY_USER="admin"
# Generate random passwords (32 chars, URL-safe)
REGISTRY_PASS=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
AUTH_SECRET=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)

# Save credentials to a local file (gitignored)
cat > "${SCRIPT_DIR}/.secrets" <<EOF
# Generated on $(date -Iseconds)
# DO NOT commit this file to git!
REGISTRY_USER=${REGISTRY_USER}
REGISTRY_PASS=${REGISTRY_PASS}
AUTH_SECRET=${AUTH_SECRET}
EOF
chmod 600 "${SCRIPT_DIR}/.secrets"

echo "=== Deploying Container Registry ==="
echo "Registry URL: http://${REGISTRY_URL}"
echo ""
echo "Credentials saved to registry/.secrets (chmod 600)"

# 1. Create namespace
echo "[1/5] Creating namespace..."
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

# 2. Generate htpasswd and create secret
echo "[2/5] Generating htpasswd & creating secret..."
HTPASSWD=$(docker run --rm httpd:2.4-alpine htpasswd -nbB "${REGISTRY_USER}" "${REGISTRY_PASS}" 2>&1)
cat > "${SCRIPT_DIR}/htpasswd-secret.yaml" <<EOF
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: registry-htpasswd
  namespace: docker-registry
stringData:
  htpasswd: |
    ${HTPASSWD}
EOF
kubectl apply -f "${SCRIPT_DIR}/htpasswd-secret.yaml"

# 3. Create auth secret (for REGISTRY_HTTP_SECRET env var)
echo "[3/5] Creating auth secret..."
cat > "${SCRIPT_DIR}/auth-secret.yaml" <<EOF
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: registry-auth
  namespace: docker-registry
stringData:
  password: "${AUTH_SECRET}"
EOF
kubectl apply -f "${SCRIPT_DIR}/auth-secret.yaml"

# 5. Create PVC
echo "[4/5] Creating persistent volume..."
kubectl apply -f "${SCRIPT_DIR}/pvc.yaml"

# 6. Deploy registry
echo "[5/5] Deploying registry..."
kubectl apply -f "${SCRIPT_DIR}/deployment.yaml"

# Wait for readiness
kubectl rollout status deployment/registry -n docker-registry --timeout=120s

echo ""
echo "=== Registry Deployed ==="
echo ""
echo "Access from Tailscale: http://${REGISTRY_URL}"
echo "Login: docker login ${REGISTRY_IP}"
echo "  username: ${REGISTRY_USER}"
echo "  password: see registry/.secrets"
echo ""
echo "Next steps:"
echo "  1. Configure k3s registries.yaml on all nodes (see /etc/rancher/k3s/registries.yaml)"
echo "  2. Run: docker push ${REGISTRY_URL}/your-image:tag"
echo "  3. Use in deployments: ${REGISTRY_URL}/your-image:tag"
echo ""
echo "Configure k3s nodes: bash ${SCRIPT_DIR}/configure-k3s.sh"
