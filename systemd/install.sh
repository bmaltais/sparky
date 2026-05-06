#!/usr/bin/env bash
set -eou pipefail

SYSTEMD_DIR=/etc/systemd/system
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for unit in "$SCRIPT_DIR"/*.service; do
  base="$(basename "$unit")"
  echo "Installing $SYSTEMD_DIR/$base"
  cp "$unit" "$SYSTEMD_DIR/$base"
done

echo "Reloading systemd daemon..."
systemctl daemon-reload

for unit in "$SCRIPT_DIR"/*.service; do
  base="$(basename "$unit")"
  echo "Enabling $base"
  systemctl enable "$base"
  echo "Starting $base"
  systemctl start "$base"
done
