#!/bin/bash

# Uninstall script for K3s and cleanup
# WARNING: This will destroy the entire cluster and all data

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }

warning "This will completely remove K3s and all cluster data!"
echo "This includes:"
echo "  - K3s cluster and all workloads"
echo "  - All persistent volumes and data"
echo "  - All container images"
echo "  - All configuration files"
echo ""
read -p "Are you absolutely sure? (type 'yes' to confirm): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo "Starting uninstall process..."

# Stop K3s service
if systemctl is-active --quiet k3s; then
    sudo systemctl stop k3s
    success "K3s service stopped"
fi

# Run K3s uninstall script if it exists
if [[ -f /usr/local/bin/k3s-uninstall.sh ]]; then
    sudo /usr/local/bin/k3s-uninstall.sh
    success "K3s uninstalled"
else
    warning "K3s uninstall script not found, performing manual cleanup"
fi

# Clean up remaining files
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf /etc/rancher/k3s
sudo rm -f /usr/local/bin/k3s
sudo rm -f /usr/local/bin/kubectl
sudo rm -f ~/.kube/config

# Clean up system configuration
sudo rm -f /etc/systemd/system/k3s.service
sudo rm -f /etc/sysctl.d/k3s.conf
sudo rm -f /etc/modules-load.d/k3s.conf

# Reload systemd
sudo systemctl daemon-reload

# Clean up container runtime
if command -v docker &> /dev/null; then
    docker system prune -af || true
fi

# Clean up iptables rules (be careful!)
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -F
sudo iptables -X

success "Uninstall completed"
echo ""
echo "Manual cleanup may be needed for:"
echo "  - Custom firewall rules"
echo "  - Modified /etc/hosts entries"
echo "  - Custom DNS configurations"
echo ""
echo "System reboot recommended to ensure clean state."