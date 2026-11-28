#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "ERROR: Run this script with sudo." >&2
  exit 1
fi

TARGET_USER="pachiabun"
BACKUP_DIR="/var/backups/ai-bum-xrdp-$(date +%Y%m%d-%H%M%S)"

echo "[1/7] Preflight checks"
id "${TARGET_USER}" >/dev/null
mkdir -p "${BACKUP_DIR}"
if [[ -f /etc/xrdp/xrdp.ini ]]; then
  cp -a /etc/xrdp/xrdp.ini "${BACKUP_DIR}/"
fi
if [[ -f /etc/xrdp/sesman.ini ]]; then
  cp -a /etc/xrdp/sesman.ini "${BACKUP_DIR}/"
fi

echo "[2/7] Stop GNOME Remote Login to release TCP 3389"
grdctl --system rdp disable 2>/dev/null || true
systemctl stop gnome-remote-desktop.service 2>/dev/null || true
systemctl mask gnome-remote-desktop.service

if ss -ltn | grep -qE ':3389[[:space:]]'; then
  echo "ERROR: TCP 3389 is still occupied; aborting before package installation." >&2
  ss -ltnp | grep -E ':3389[[:space:]]' || true
  systemctl unmask gnome-remote-desktop.service || true
  systemctl start gnome-remote-desktop.service || true
  exit 1
fi

echo "[3/7] Install Ubuntu xrdp packages"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y xrdp xorgxrdp

echo "[4/7] Permit xrdp to read its TLS certificate"
adduser xrdp ssl-cert >/dev/null

echo "[5/7] Enable xrdp services"
systemctl enable xrdp-sesman.service xrdp.service
# Restart is required so the already-running xrdp process inherits its new
# ssl-cert supplementary group after `adduser xrdp ssl-cert` above.
systemctl restart xrdp-sesman.service xrdp.service

echo "[6/7] Keep RDP private to Tailscale in UFW"
if command -v ufw >/dev/null 2>&1; then
  ufw allow in on tailscale0 to any port 3389 proto tcp comment 'XRDP via Tailscale' >/dev/null
fi

echo "[7/7] Verification"
systemctl --no-pager --full status xrdp.service xrdp-sesman.service | sed -n '1,24p'
ss -ltnp | grep -E ':3389[[:space:]]'

echo
echo "XRDP_INSTALL_OK"
echo "Backup directory: ${BACKUP_DIR}"
echo "No reboot was performed."
