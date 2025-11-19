#!/bin/bash

# K3s Installation Script for A1 Node
# Installs K3s with security hardening and proper node configuration

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# System requirements check
check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check RAM (minimum 16GB)
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $total_ram -lt 15 ]]; then
        log_error "Insufficient RAM: ${total_ram}GB (minimum 16GB required)"
        exit 1
    fi
    
    # Check CPU cores (minimum 8)
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt 8 ]]; then
        log_error "Insufficient CPU cores: ${cpu_cores} (minimum 8 required)"
        exit 1
    fi
    
    # Check disk space (minimum 100GB available)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    if [[ $available_gb -lt 100 ]]; then
        log_error "Insufficient disk space: ${available_gb}GB (minimum 100GB required)"
        exit 1
    fi
    
    log_success "System requirements check passed"
    log_info "System specs: ${total_ram}GB RAM, ${cpu_cores} CPU cores, ${available_gb}GB available disk"
}

# Configure firewall
configure_firewall() {
    log_info "Configuring firewall..."
    
    # Install firewall if not present
    if ! command -v ufw &> /dev/null; then
        apt-get update && apt-get install -y ufw
    fi
    
    # Reset firewall rules
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # SSH access
    ufw allow 22/tcp
    
    # K3s API server
    ufw allow 6443/tcp
    
    # Kubelet metrics
    ufw allow 10250/tcp
    
    # Node ports (if needed)
    ufw allow 30000:32767/tcp
    
    # Enable firewall
    ufw --force enable
    
    log_success "Firewall configured"
}

# Configure kernel parameters
setup_kernel_parameters() {
    log_info "Configuring kernel parameters for K3s..."
    
    cat > /etc/sysctl.d/99-kubernetes.conf << EOF
# Kubernetes networking
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1

# Security hardening
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Memory management
vm.overcommit_memory = 1
vm.panic_on_oom = 0
vm.swappiness = 1
EOF

    # Apply kernel parameters
    sysctl --system
    
    log_success "Kernel parameters configured"
}

# Create audit policy
create_audit_policy() {
    log_info "Creating Kubernetes audit policy..."
    
    mkdir -p /var/lib/rancher/k3s/server
    
    cat > /var/lib/rancher/k3s/server/audit-policy.yaml << EOF
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Log requests to sensitive resources
  - level: Metadata
    namespaces: ["kube-system", "argocd", "gatekeeper-system"]
    resources:
    - group: ""
      resources: ["secrets", "configmaps"]
    
  # Log all requests to the API server
  - level: Request
    namespaces: ["orchestrator"]
    
  # Log authentication failures
  - level: Metadata
    omitStages:
      - RequestReceived
    resources:
    - group: ""
      resources: ["events"]
    
  # Default: log metadata for everything else
  - level: Metadata
    omitStages:
      - RequestReceived
EOF

    log_success "Audit policy created"
}

# Install K3s
install_k3s() {
    log_info "Installing K3s with security hardening..."
    
    # Create audit policy first
    create_audit_policy
    
    # Install K3s with custom configuration
    INSTALL_K3S_EXEC="server --write-kubeconfig-mode=644 --disable=traefik" \
    curl -sfL https://get.k3s.io | sh -s - server \
        --write-kubeconfig-mode 644 \
        --disable=traefik \
        --kubelet-arg="protect-kernel-defaults=true" \
        --kube-apiserver-arg="audit-log-path=/var/lib/rancher/k3s/server/logs/audit.log" \
        --kube-apiserver-arg="audit-policy-file=/var/lib/rancher/k3s/server/audit-policy.yaml" \
        --kube-apiserver-arg="audit-log-maxage=30" \
        --kube-apiserver-arg="audit-log-maxbackup=10" \
        --kube-apiserver-arg="audit-log-maxsize=100" \
        --kube-apiserver-arg="enable-admission-plugins=NodeRestriction" \
        --kube-apiserver-arg="anonymous-auth=false" \
        --disable local-storage

    if [[ $? -eq 0 ]]; then
        log_success "K3s installation completed successfully"
    else
        log_error "K3s installation failed"
        exit 1
    fi
    
    # Set proper permissions
    chmod 644 /etc/rancher/k3s/k3s.yaml
    
    # Label and taint the node
    log_info "Configuring node labels and taints..."
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    
    # Wait for node to be ready
    local attempts=0
    while ! kubectl get nodes | grep -q "Ready"; do
        log_info "Waiting for node to be ready... (attempt $((++attempts))/60)"
        if [[ $attempts -ge 60 ]]; then
            log_error "Timeout waiting for node to be ready"
            exit 1
        fi
        sleep 5
    done
    
    # Get node name
    NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    
    # Label the node
    kubectl label node $NODE_NAME node-role=control host=A1 --overwrite
    
    # Taint the node
    kubectl taint node $NODE_NAME dedicated=control:NoSchedule --overwrite
    
    log_success "Node labels and taints configured"
}

# Verify installation
verify_installation() {
    log_info "Verifying K3s installation..."
    
    # Check if K3s service is running
    if systemctl is-active --quiet k3s; then
        log_success "K3s service is running"
    else
        log_error "K3s service is not running"
        exit 1
    fi
    
    # Check if kubectl works
    if kubectl get nodes &> /dev/null; then
        log_success "kubectl is working"
    else
        log_error "kubectl is not working"
        exit 1
    fi
    
    # Display cluster info
    log_info "Cluster information:"
    kubectl get nodes -o wide
    kubectl get pods -A
}

# Main execution
main() {
    log_info "Starting K3s installation for A1 node..."
    echo "======================================="
    
    check_root
    check_system_requirements
    configure_firewall
    setup_kernel_parameters
    install_k3s
    verify_installation
    
    echo "======================================="
    log_success "K3s installation completed successfully!"
    log_info "Next steps:"
    echo "1. Run: ./infra/02-kubeconfig-export.sh"
    echo "2. Run: ./infra/03-terraform-bootstrap.sh"
    echo "3. Deploy applications with ArgoCD"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi