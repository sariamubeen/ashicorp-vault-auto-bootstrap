# hashicorp-vault-auto-bootstrap

Welcome to the **automated Vault installation script** by [@sariamubeen](https://github.com/sariamubeen) — a fully hands-free setup for HashiCorp Vault using Raft storage on Ubuntu.

## 🚀 Features

- ✅ Fully automated, zero user input
- ⚙️ Uses Raft as the storage backend
- 🔒 Automatically initializes and unseals Vault
- 📦 Installs dependencies and sets up systemd service
- 📝 Saves root token and unseal key securely to `/root/vault-init-output.json`

---

## 🖥️ Supported Environment

- OS: Ubuntu 20.04 / 22.04 (or compatible)
- Network: Localhost (Vault binds to `127.0.0.1`)

---

## 📦 What It Does

This script will:
1. Install Vault and required packages
2. Create secure config files for Vault
3. Set up and enable the Vault systemd service
4. Initialize Vault and automatically unseal it
5. Output the root token for immediate login

---

## 📁 Files & Output

| File                                | Purpose                            |
|-------------------------------------|------------------------------------|
| `/etc/vault.d/config.hcl`           | Base Vault config                  |
| `/etc/vault.d/vault.hcl`            | Storage + listener configuration   |
| `/opt/vault/data`                   | Raft data directory                |
| `/etc/systemd/system/vault.service` | Systemd service definition         |
| `/root/vault-init-output.json`      | Contains unseal key + root token  |

---

## 🔐 How to Login to Vault

After the script finishes, it prints the root token to the console:

```bash
export VAULT_ADDR=http://127.0.0.1:8200
vault login <root-token>
```

You can also get the token from the saved file:

```bash
jq -r .root_token /root/vault-init-output.json
```

---

## 🧪 Usage

```bash
git clone https://github.com/sariamubeen/hashicorp-vault-auto-bootstrap.git
cd hashicorp-vault-auto-bootstrap
sudo ./vault-setup.sh
```

---

## ⚠️ Disclaimer
This is intended for local dev/test use. For production:
- Use TLS
- Use auto-unseal with a KMS provider
- Harden permissions and network exposure

---

## 📬 Feedback / Contributions
PRs and issues welcome at [github.com/sariamubeen](https://github.com/sariamubeen) 🙌

---

**Created with ❤️ by [@sariamubeen](https://github.com/sariamubeen)**

