#!/bin/bash

# Kubeconfig Export Script for A1 Node
# Exports K3s kubeconfig to user's ~/.kube/config

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

# Export kubeconfig for local access
export_local_kubeconfig() {
    log_info "Copying kubeconfig to user's .kube/config..."
    
    if [[ ! -f "/etc/rancher/k3s/k3s.yaml" ]]; then
        log_error "K3s kubeconfig not found. Is K3s installed?"
        return 1
    fi
    
    # Create .kube directory if it doesn't exist
    mkdir -p "$HOME/.kube"
    
    # Copy /etc/rancher/k3s/k3s.yaml to ~/.kube/config
    sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
    sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
    chmod 600 "$HOME/.kube/config"
    
    log_success "Kubeconfig exported to $HOME/.kube/config"
    
    # Verify kubectl works
    if kubectl cluster-info &> /dev/null; then
        log_success "kubectl is working with local config"
        kubectl get nodes
    else
        log_error "kubectl is not working with local config"
        return 1
    fi
}

# Export kubeconfig for external access
export_external_kubeconfig() {
    local external_ip="$1"
    local output_file="$2"
    
    log_info "Creating external kubeconfig for IP: $external_ip"
    
    if [[ ! -f "/etc/rancher/k3s/k3s.yaml" ]]; then
        log_error "K3s kubeconfig not found. Is K3s installed?"
        return 1
    fi
    
    # Copy kubeconfig and replace server IP
    sudo cp /etc/rancher/k3s/k3s.yaml "$output_file"
    sudo chown "$(id -u):$(id -g)" "$output_file"
    chmod 600 "$output_file"
    
    # Replace localhost with external IP
    sed -i "s/127.0.0.1:6443/$external_ip:6443/g" "$output_file"
    
    log_success "External kubeconfig created: $output_file"
    log_info "Use: export KUBECONFIG=$output_file"
}

# Create CI/CD service account and token
create_cicd_service_account() {
    log_info "Creating CI/CD service account..."
    
    # Create service account manifest
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cicd-deployer
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cicd-deployer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: cicd-deployer
  namespace: kube-system
---
apiVersion: v1
kind: Secret
metadata:
  name: cicd-deployer-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: cicd-deployer
type: kubernetes.io/service-account-token
EOF

    # Wait for token to be created
    log_info "Waiting for service account token..."
    local attempts=0
    while [[ $attempts -lt 30 ]]; do
        if kubectl get secret cicd-deployer-token -n kube-system &> /dev/null; then
            break
        fi
        sleep 2
        ((attempts++))
    done
    
    if [[ $attempts -ge 30 ]]; then
        log_error "Timeout waiting for service account token"
        return 1
    fi
    
    # Get token and create kubeconfig
    local token=$(kubectl get secret cicd-deployer-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)
    local ca_cert=$(kubectl get secret cicd-deployer-token -n kube-system -o jsonpath='{.data.ca\.crt}')
    
    # Create CI/CD kubeconfig
    cat > "$HOME/.kube/cicd-config" << EOF
apiVersion: v1
kind: Config
current-context: a1-cicd
contexts:
- context:
    cluster: a1-cluster
    user: cicd-deployer
  name: a1-cicd
clusters:
- cluster:
    certificate-authority-data: $ca_cert
    server: https://127.0.0.1:6443
  name: a1-cluster
users:
- name: cicd-deployer
  user:
    token: $token
EOF
    
    chmod 600 "$HOME/.kube/cicd-config"
    
    log_success "CI/CD kubeconfig created: $HOME/.kube/cicd-config"
    log_info "Use: export KUBECONFIG=$HOME/.kube/cicd-config"
}

# Display usage information
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  local                    Export kubeconfig for local access (default)"
    echo "  external <ip> [file]     Export kubeconfig for external access"
    echo "  cicd                     Create CI/CD service account and token"
    echo "  help                     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Export for local access"
    echo "  $0 local                              # Same as above"
    echo "  $0 external 192.168.1.100             # Export for external access"
    echo "  $0 external 192.168.1.100 ~/kubeconfig # Custom output file"
    echo "  $0 cicd                               # Create CI/CD credentials"
}

# Validate access
validate_access() {
    log_info "Validating cluster access..."
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access Kubernetes cluster"
        return 1
    fi
    
    if ! kubectl auth can-i get nodes &> /dev/null; then
        log_warning "Limited permissions - some operations may fail"
    fi
    
    log_success "Cluster access validated"
    kubectl get nodes -o wide
}

# Main execution
main() {
    local command="${1:-local}"
    
    case "$command" in
        "local")
            export_local_kubeconfig
            validate_access
            ;;
        "external")
            if [[ $# -lt 2 ]]; then
                log_error "External IP address required"
                show_usage
                exit 1
            fi
            local external_ip="$2"
            local output_file="${3:-$HOME/.kube/external-config}"
            export_external_kubeconfig "$external_ip" "$output_file"
            ;;
        "cicd")
            export_local_kubeconfig
            create_cicd_service_account
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi