#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "This installer must be run as root"
  exit 1
fi

apt update
apt install -y bluetooth bluez

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install locations
HCI_DIR=/opt/bluetooth-proxy
DBUS_DIR=/opt/dbus-proxy
SYSTEMD_DIR=/etc/systemd/system

mkdir -p "$HCI_DIR" "$DBUS_DIR"

# Copy files from repo root (flat layout)
cp "$REPO_ROOT/hci-proxy.sh" "$HCI_DIR/hci-proxy.sh"
cp "$REPO_ROOT/dbus-proxy.sh" "$DBUS_DIR/dbus-proxy.sh"
cp "$REPO_ROOT/bluetooth-proxy.service" "$SYSTEMD_DIR/bluetooth-proxy.service"
cp "$REPO_ROOT/dbus-proxy.service" "$SYSTEMD_DIR/dbus-proxy.service"

# Make the scripts executable
chmod 0755 "$HCI_DIR/hci-proxy.sh" "$DBUS_DIR/dbus-proxy.sh"

# Reload systemd and enable/start services
systemctl daemon-reload
systemctl enable --now bluetooth-proxy.service
systemctl enable --now dbus-proxy.service

echo "Installation complete. Services enabled and started."
