#!/usr/bin/env bash
set -euo pipefail

REGISTRY_IP="100.101.186.51"
REGISTRY_PORT=5000
REGISTRIES_FILE="/etc/rancher/k3s/registries.yaml"

echo "=== Configuring k3s registries.yaml on all nodes ==="
echo "Registry: ${REGISTRY_IP}:${REGISTRY_PORT}"
echo ""

# Function to write and restart on a node
configure_node() {
  local label="$1"
  local user="$2"
  local host="$3"
  local local_node="$4"  # "true" or "false"

  echo "[*] Configuring ${label}..."

  if [ "$local_node" = "true" ]; then
    sudo mkdir -p /etc/rancher/k3s
    sudo tee "$REGISTRIES_FILE" > /dev/null <<EOF
# k3s registry configuration
registries:
  configs:
    "${REGISTRY_IP}:${REGISTRY_PORT}":
      insecure: true
EOF
    sudo systemctl restart k3s
  else
    ssh -o StrictHostKeyChecking=no ${user}@${host} "
      sudo mkdir -p /etc/rancher/k3s
      sudo tee ${REGISTRIES_FILE} > /dev/null <<'EOF'
# k3s registry configuration
registries:
  configs:
    '${REGISTRY_IP}:${REGISTRY_PORT}':
      insecure: true
EOF
      sudo systemctl restart k3s
    "
  fi
  echo "  -> Done."
  echo ""
}

configure_node "mini1 (local)" "bernard" "127.0.0.1" "true"
configure_node "mini2" "bernard" "mini2" "false"
configure_node "vps1" "bernard" "vps1" "false"
configure_node "vps2" "bernard" "vps2" "false"

echo "=== k3s registries.yaml configured on all nodes ==="
echo ""
echo "Verify: kubectl get pods -n docker-registry"
