#!/bin/bash

# === Exit immediately on error, undefined var, or pipe failure ===
set -euo pipefail

# === ROOT USER CHECK ===
if [[ "$(id -u)" -ne 0 ]]; then
  echo -e "\n❌ This script must be run as root (UID 0)."
  echo "💡 Try again using: sudo $0"
  exit 1
fi

# === Wait for APT Lock ===
wait_for_apt_lock() {
    local timeout=120  # total seconds to wait
    local waited=0
    local interval=5

    echo -e "\n⏳ Waiting for APT lock to be released (timeout: ${timeout}s)..."
    while fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
          fuser /var/lib/dpkg/lock >/dev/null 2>&1 || \
          fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        if [[ "$waited" -ge "$timeout" ]]; then
            echo -e "❌ Timeout reached while waiting for APT lock. Please try again later."
            exit 1
        fi
        echo "🔒 APT is locked. Waiting... (${waited}s elapsed)"
        sleep "$interval"
        waited=$((waited + interval))
    done
    echo "✅ APT lock is free. Proceeding..."
}

# === Set paths ===
VAULT_CONFIG_DIR="/etc/vault.d"
VAULT_DATA_DIR="/opt/vault/data"
mkdir -p "$VAULT_CONFIG_DIR" "$VAULT_DATA_DIR"

# === Install dependencies ===
echo "🔧 Installing system dependencies..."
wait_for_apt_lock
export DEBIAN_FRONTEND=noninteractive
apt update
sleep 2
apt install -y curl unzip gnupg lsb-release jq

# === Install Vault ===
echo "📦 Adding HashiCorp GPG key and APT repo..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list

apt update

echo "📦 Installing Vault..."
apt install -y vault
if command -v vault >/dev/null 2>&1; then
  vault -v
else
  echo "⚠️ Vault is not found in PATH. Installation may have failed."
fi

# === Auto-configure ===
VAULT_IP="127.0.0.1"
NODE_ID="node-$(hostname)"

# === Create config.hcl ===
echo "📝 Creating Vault base config..."
tee "${VAULT_CONFIG_DIR}/config.hcl" > /dev/null <<EOF
ui            = true
disable_mlock = true
EOF

# === Create vault.hcl ===
echo "📝 Creating Vault Raft and listener config..."
tee "${VAULT_CONFIG_DIR}/vault.hcl" > /dev/null <<EOF
api_addr     = "http://${VAULT_IP}:8200"
cluster_addr = "http://${VAULT_IP}:8201"

storage "raft" {
  path    = "${VAULT_DATA_DIR}"
  node_id = "${NODE_ID}"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = 1
}
EOF

# === Create systemd service ===
echo "⚙️ Setting up Vault systemd service..."
tee /etc/systemd/system/vault.service > /dev/null <<EOF
[Unit]
Description=HashiCorp Vault
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/vault server -config=${VAULT_CONFIG_DIR}
ExecReload=/bin/kill --signal HUP \$MAINPID
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# === Enable and start Vault ===
echo "🚀 Starting Vault..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable vault
systemctl start vault
sleep 3

# === Initialize Vault ===
echo "🔐 Initializing Vault..."
export VAULT_ADDR="http://${VAULT_IP}:8200"
INIT_OUTPUT=$(vault operator init -key-shares=1 -key-threshold=1 -format=json)
echo "$INIT_OUTPUT" > /root/vault-init-output.json

UNSEAL_KEY=$(echo "$INIT_OUTPUT" | jq -r .unseal_keys_b64[0])
ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r .root_token)

# === Unseal Vault ===
echo "🔓 Unsealing Vault..."
vault operator unseal "$UNSEAL_KEY"

# === Show Token ===
echo -e "\n✅ Vault is ready! Use this token to login:"
echo "$ROOT_TOKEN"
echo "📁 Init output saved at: /root/vault-init-output.json"
