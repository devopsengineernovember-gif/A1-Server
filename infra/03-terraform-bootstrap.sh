#!/bin/bash

# Terraform Bootstrap Script for A1 Platform
# Deploys platform components using Terraform and Helm

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check if terraform is available
    if ! command -v terraform &> /dev/null; then
        log_error "terraform not found. Please install Terraform."
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access Kubernetes cluster. Please check kubeconfig."
        exit 1
    fi
    
    # Check if we're in the right directory
    if [[ ! -d "terraform/platform" ]]; then
        log_error "terraform/platform directory not found. Please run from repository root."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Initialize Terraform
init_terraform() {
    log_info "Initializing Terraform..."
    
    cd terraform/platform
    
    terraform init
    
    if [[ $? -eq 0 ]]; then
        log_success "Terraform initialized successfully"
    else
        log_error "Terraform initialization failed"
        exit 1
    fi
    
    cd ../..
}

# Plan Terraform deployment
plan_terraform() {
    log_info "Planning Terraform deployment..."
    
    cd terraform/platform
    
    terraform plan -out=tfplan
    
    if [[ $? -eq 0 ]]; then
        log_success "Terraform plan completed successfully"
    else
        log_error "Terraform plan failed"
        exit 1
    fi
    
    cd ../..
}

# Apply Terraform deployment
apply_terraform() {
    log_info "Applying Terraform deployment..."
    
    cd terraform/platform
    
    terraform apply tfplan
    
    if [[ $? -eq 0 ]]; then
        log_success "Terraform apply completed successfully"
    else
        log_error "Terraform apply failed"
        exit 1
    fi
    
    cd ../..
}

# Wait for platform components to be ready
wait_for_components() {
    log_info "Waiting for platform components to be ready..."
    
    # Wait for ArgoCD
    log_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-repo-server -n argocd
    
    # Wait for Gatekeeper
    log_info "Waiting for Gatekeeper to be ready..."
    kubectl wait --for=condition=available --timeout=600s deployment/gatekeeper-controller-manager -n gatekeeper-system
    
    # Wait for External Secrets
    log_info "Waiting for External Secrets to be ready..."
    kubectl wait --for=condition=available --timeout=600s deployment/external-secrets -n external-secrets
    
    # Wait for KEDA
    log_info "Waiting for KEDA to be ready..."
    kubectl wait --for=condition=available --timeout=600s deployment/keda-operator -n keda
    
    # Wait for Prometheus
    log_info "Waiting for Prometheus stack to be ready..."
    kubectl wait --for=condition=available --timeout=600s deployment/prometheus-grafana -n observability
    
    log_success "All platform components are ready"
}

# Apply additional manifests
apply_manifests() {
    log_info "Applying additional manifests..."
    
    # Apply Gatekeeper constraints
    if [[ -f "policies/gatekeeper-constraints.yaml" ]]; then
        log_info "Applying Gatekeeper constraints..."
        kubectl apply -f policies/gatekeeper-constraints.yaml
        log_success "Gatekeeper constraints applied"
    else
        log_warning "Gatekeeper constraints file not found"
    fi
    
    # Apply ArgoCD root application
    if [[ -f "apps/root-app/app-of-apps.yaml" ]]; then
        log_info "Applying ArgoCD root application..."
        kubectl apply -f apps/root-app/app-of-apps.yaml
        log_success "ArgoCD root application applied"
    else
        log_warning "ArgoCD root application file not found"
    fi
}

# Display access information
show_access_info() {
    log_info "Platform access information:"
    echo ""
    
    # ArgoCD access
    echo "ArgoCD UI:"
    echo "  Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  URL: https://localhost:8080"
    echo "  Username: admin"
    echo "  Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo 'Not available yet')"
    echo ""
    
    # Grafana access
    echo "Grafana Dashboard:"
    echo "  Port-forward: kubectl port-forward svc/prometheus-grafana -n observability 3000:80"
    echo "  URL: http://localhost:3000"
    echo "  Username: admin"
    echo "  Password: prom-operator"
    echo ""
    
    # Prometheus access
    echo "Prometheus:"
    echo "  Port-forward: kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n observability 9090:9090"
    echo "  URL: http://localhost:9090"
    echo ""
    
    log_info "To access services, run the port-forward commands above"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    if [[ -f "terraform/platform/tfplan" ]]; then
        rm terraform/platform/tfplan
    fi
}

# Main execution
main() {
    log_info "Starting Terraform bootstrap for A1 platform..."
    echo "======================================="
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    check_prerequisites
    init_terraform
    plan_terraform
    apply_terraform
    wait_for_components
    apply_manifests
    show_access_info
    
    echo "======================================="
    log_success "Platform bootstrap completed successfully!"
    log_info "Next steps:"
    echo "1. Access ArgoCD UI to monitor application deployments"
    echo "2. Check Grafana for monitoring dashboards"
    echo "3. Run smoke tests: ./infra/smoke-tests-a1.sh"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi