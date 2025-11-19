#!/bin/bash

# K3s Installation Script for A1 Node
# Configures single-node K3s cluster with security hardening

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() { echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"; }
warning() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"; exit 1; }

# Configuration
K3S_VERSION="v1.28.4+k3s1"
NODE_NAME="a1"
CLUSTER_DOMAIN="a1.local"

# System requirements check
check_requirements() {
    log "Checking system requirements..."
    
    # Check if running as root or with sudo
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Use sudo when needed."
    fi
    
    # Check available memory (should be >= 16GB)
    local mem_gb=$(free -g | awk 'NR==2{print $2}')
    if [[ $mem_gb -lt 15 ]]; then
        error "Insufficient memory. Required: 16GB, Available: ${mem_gb}GB"
    fi
    success "Memory check passed: ${mem_gb}GB available"
    
    # Check CPU cores (should be >= 8)
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt 8 ]]; then
        error "Insufficient CPU cores. Required: 8, Available: ${cpu_cores}"
    fi
    success "CPU check passed: ${cpu_cores} cores available"
    
    # Check disk space (should be >= 100GB available)
    local disk_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $disk_gb -lt 100 ]]; then
        warning "Low disk space. Available: ${disk_gb}GB (recommended: 100GB+)"
    else
        success "Disk space check passed: ${disk_gb}GB available"
    fi
    
    # Check if K3s is already installed
    if command -v k3s &> /dev/null; then
        warning "K3s is already installed. Use uninstall.sh first if you want to reinstall."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# Configure system prerequisites
configure_system() {
    log "Configuring system prerequisites..."
    
    # Disable swap (required for K3s)
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    success "Swap disabled"
    
    # Configure kernel modules
    sudo modprobe overlay
    sudo modprobe br_netfilter
    
    # Make modules persistent
    cat <<EOF | sudo tee /etc/modules-load.d/k3s.conf
overlay
br_netfilter
EOF
    
    # Configure kernel parameters
    cat <<EOF | sudo tee /etc/sysctl.d/k3s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv4.conf.all.forwarding        = 1
net.ipv6.conf.all.forwarding        = 1
EOF
    
    sudo sysctl --system
    success "Kernel parameters configured"
    
    # Configure firewall if ufw is active
    if systemctl is-active --quiet ufw; then
        log "Configuring firewall rules..."
        sudo ufw allow 6443/tcp  # K3s API
        sudo ufw allow 2379:2380/tcp  # etcd
        sudo ufw allow 10250/tcp  # Kubelet
        sudo ufw allow 30000:32767/tcp  # NodePort range
        success "Firewall rules configured"
    fi
}

# Install K3s with security hardening
install_k3s() {
    log "Installing K3s ${K3S_VERSION}..."
    
    # Create K3s configuration directory
    sudo mkdir -p /etc/rancher/k3s
    
    # Create K3s configuration file with security hardening
    cat <<EOF | sudo tee /etc/rancher/k3s/config.yaml
# K3s server configuration
write-kubeconfig-mode: "0644"
cluster-domain: "${CLUSTER_DOMAIN}"
node-name: "${NODE_NAME}"

# Security hardening
protect-kernel-defaults: true
secrets-encryption: true
kube-controller-manager-arg:
  - "bind-address=127.0.0.1"
  - "secure-port=10257"
  - "terminated-pod-gc-threshold=10"
kube-scheduler-arg:
  - "bind-address=127.0.0.1"
  - "secure-port=10259"
kube-apiserver-arg:
  - "audit-log-maxage=30"
  - "audit-log-maxbackup=3"
  - "audit-log-maxsize=100"
  - "audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log"
  - "request-timeout=300s"
  - "service-account-lookup=true"
  - "enable-admission-plugins=NodeRestriction,NamespaceLifecycle,ServiceAccount,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook"

# Disable bundled addons (we'll manage them with Terraform)
disable:
  - traefik
  - servicelb
  - metrics-server

# Enable embedded components
disable-helm-controller: false
disable-kube-proxy: false
disable-network-policy: false

# Cluster networking
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"
cluster-dns: "10.43.0.10"

# Node configuration
node-label:
  - "node.kubernetes.io/instance-type=control-plane"
  - "topology.kubernetes.io/zone=a1"
  - "ai-platform.cisco.com/role=orchestrator"
node-taint:
  - "node-role.kubernetes.io/control-plane:NoSchedule"
EOF
    
    # Install K3s
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - server
    
    # Wait for K3s to be ready
    log "Waiting for K3s to be ready..."
    local timeout=300
    local elapsed=0
    while ! sudo k3s kubectl get nodes "${NODE_NAME}" --no-headers | grep -q Ready; do
        if [[ $elapsed -ge $timeout ]]; then
            error "Timeout waiting for K3s to be ready"
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    success "K3s installed and ready"
}

# Configure kubectl access
configure_kubectl() {
    log "Configuring kubectl access..."
    
    # Copy kubeconfig for current user
    mkdir -p "$HOME/.kube"
    sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
    sudo chown "$USER:$USER" "$HOME/.kube/config"
    chmod 600 "$HOME/.kube/config"
    
    # Update server address if needed
    sed -i "s/127.0.0.1/$(hostname -I | awk '{print $1}')/g" "$HOME/.kube/config"
    
    success "kubectl configured for user $USER"
    
    # Verify cluster access
    if kubectl cluster-info &> /dev/null; then
        success "Cluster access verified"
    else
        error "Failed to access cluster"
    fi
}

# Install additional tools
install_tools() {
    log "Installing additional tools..."
    
    # Install Helm
    if ! command -v helm &> /dev/null; then
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        success "Helm installed"
    else
        log "Helm already installed: $(helm version --short)"
    fi
    
    # Install Terraform if not present
    if ! command -v terraform &> /dev/null; then
        log "Installing Terraform..."
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update && sudo apt install -y terraform
        success "Terraform installed"
    else
        log "Terraform already installed: $(terraform version | head -n1)"
    fi
    
    # Install kubectl if not present (usually comes with K3s)
    if ! command -v kubectl &> /dev/null; then
        log "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        success "kubectl installed"
    else
        log "kubectl already available"
    fi
}

# Configure node labels and taints for production
configure_node() {
    log "Configuring node labels and taints..."
    
    # Add production labels
    kubectl label node "${NODE_NAME}" \
        kubernetes.io/role=control-plane \
        node-role.kubernetes.io/control-plane="" \
        ai-platform.cisco.com/node-type=all-in-one \
        ai-platform.cisco.com/tier=control-plane \
        --overwrite
    
    # Allow scheduling on control plane for single-node setup
    kubectl taint nodes "${NODE_NAME}" node-role.kubernetes.io/control-plane:NoSchedule-
    
    success "Node configuration completed"
}

# Display cluster information
show_cluster_info() {
    log "Cluster installation completed!"
    echo ""
    echo "==================================================================="
    echo "🚀 K3s Cluster Ready!"
    echo "==================================================================="
    echo ""
    echo "📊 Cluster Information:"
    kubectl cluster-info
    echo ""
    echo "🖥️  Node Status:"
    kubectl get nodes -o wide
    echo ""
    echo "📦 System Pods:"
    kubectl get pods -n kube-system
    echo ""
    echo "🔧 Configuration:"
    echo "  Kubeconfig: $HOME/.kube/config"
    echo "  Server config: /etc/rancher/k3s/config.yaml"
    echo "  Data directory: /var/lib/rancher/k3s"
    echo ""
    echo "🔗 API Server: https://$(hostname -I | awk '{print $1}'):6443"
    echo "🏷️  Cluster Domain: ${CLUSTER_DOMAIN}"
    echo ""
    echo "📋 Next Steps:"
    echo "  1. cd terraform && terraform init && terraform apply"
    echo "  2. Access ArgoCD UI after Terraform completes"
    echo "  3. Deploy AI agents via ArgoCD"
    echo ""
    echo "==================================================================="
}

# Main execution
main() {
    log "Starting K3s installation for A1 node..."
    
    check_requirements
    configure_system
    install_k3s
    configure_kubectl
    install_tools
    configure_node
    show_cluster_info
    
    success "K3s installation completed successfully!"
}

# Run main function
main "$@"