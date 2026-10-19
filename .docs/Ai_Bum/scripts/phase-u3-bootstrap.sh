#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script with: sudo bash $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

echo "[1/6] Update Ubuntu packages"
apt-get update
apt-get full-upgrade -y

echo "[2/6] Install base administration packages"
apt-get install -y ca-certificates curl ufw

echo "[3/6] Add the official Tailscale repository for Ubuntu 24.04 (Noble)"
install -d -m 0755 /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
  -o /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list \
  -o /etc/apt/sources.list.d/tailscale.list
apt-get update
apt-get install -y tailscale
systemctl enable --now tailscaled

echo "[4/6] Configure a fail-closed host firewall"
ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.168.1.0/24 to any port 22 proto tcp comment 'SSH from LAN'
ufw allow in on tailscale0 to any port 22 proto tcp comment 'SSH over Tailscale'
ufw allow in on tailscale0 to any port 3389 proto tcp comment 'RDP login over Tailscale'
ufw allow in on tailscale0 to any port 3390 proto tcp comment 'RDP sharing over Tailscale'
ufw --force enable

echo "[5/6] Prevent unattended server sleep/hibernate"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

echo "[6/6] Report status (no reboot is performed)"
systemctl --no-pager --full status ssh tailscaled | sed -n '1,40p'
ufw status verbose

cat <<'EOF'

Phase U3 bootstrap finished.
Next, authenticate this server to the tailnet manually:
  sudo tailscale up

Do not disable SSH password authentication and do not reboot yet.
EOF
