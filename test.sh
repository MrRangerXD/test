#!/bin/bash
dpkg --configure -a
set -e

echo "[+] Starting Debian → Proxmox conversion..."

# ===== Safety check =====
if [ "$EUID" -ne 0 ]; then
  echo "Run as root ❌"
  exit 1
fi

# ===== Hostname fix =====
echo "[+] Setting hostname..."
hostnamectl set-hostname proxmox

IP=$(hostname -I | awk '{print $1}')
echo "127.0.0.1 localhost" > /etc/hosts
echo "$IP proxmox.local proxmox" >> /etc/hosts

# ===== Add Proxmox repo =====
echo "[+] Adding Proxmox repo..."
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" \
> /etc/apt/sources.list.d/pve.list

# ===== Add GPG key =====
echo "[+] Adding GPG key..."
wget -qO /etc/apt/trusted.gpg.d/proxmox.gpg \
https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg
rm -f /etc/apt/sources.list.d/pve-enterprise.list
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" \
> /etc/apt/sources.list.d/pve.list
# ===== Update system =====
echo "[+] Updating system..."
apt update
apt full-upgrade -y

# ===== Install Proxmox =====
echo "[+] Installing Proxmox VE..."
DEBIAN_FRONTEND=noninteractive apt install -y proxmox-ve postfix open-iscsi

# ===== Remove Debian kernel =====
echo "[+] Switching to Proxmox kernel..."
apt remove -y linux-image-amd64 || true
update-grub

# ===== Enable services =====
systemctl enable pveproxy
systemctl enable pvedaemon
systemctl enable pve-cluster
sudo reboot
# ===== Done =====
echo ""
echo "🔥 DONE! Proxmox installed"
echo "👉 Reboot now:"
echo "reboot"
echo ""
echo "🌐 After reboot open:"
echo "https://$IP:8006"
echo ""
echo "Login: root (same password)"