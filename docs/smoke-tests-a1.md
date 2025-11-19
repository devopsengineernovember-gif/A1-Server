#!/bin/bash

# A1 Platform Smoke Tests
# Comprehensive health checks for the A1 AI Orchestrator Platform

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
NAMESPACE="a1-orchestrator"
TIMEOUT=300
RETRY_COUNT=3

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

# Test result tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_info "Running test: $test_name"
    
    if eval "$test_command"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log_success "$test_name passed"
        return 0
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log_error "$test_name failed"
        return 1
    fi
}

# Prerequisites check
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Test 1: Cluster health
test_cluster_health() {
    kubectl get nodes --no-headers | grep -q "Ready" && \
    kubectl get componentstatuses --no-headers | grep -v "Unhealthy"
}

# Test 2: Namespace existence
test_namespace_exists() {
    kubectl get namespace $NAMESPACE &> /dev/null
}

# Test 3: All pods are running
test_pods_running() {
    local not_running=$(kubectl get pods -n $NAMESPACE --no-headers | grep -v "Running" | grep -v "Completed" | wc -l)
    [ "$not_running" -eq 0 ]
}

# Test 4: Service endpoints
test_service_endpoints() {
    local services=(
        "mcp-gateway"
        "mcp-orchestrator-api"
        "mcp-policy-proxy"
        "mcp-config"
        "mcp-tracehub"
    )
    
    for service in "${services[@]}"; do
        kubectl get endpoints -n $NAMESPACE $service -o jsonpath='{.subsets[0].addresses[0].ip}' | grep -q "."
        if [ $? -ne 0 ]; then
            return 1
        fi
    done
    return 0
}

# Test 5: Service health checks
test_service_health() {
    local services=(
        "mcp-gateway:8080"
        "mcp-orchestrator-api:8080"
        "mcp-policy-proxy:8080"
        "mcp-config:8080"
        "mcp-tracehub:8080"
    )
    
    for service in "${services[@]}"; do
        local service_name=$(echo $service | cut -d: -f1)
        local port=$(echo $service | cut -d: -f2)
        
        # Port forward and test
        kubectl port-forward -n $NAMESPACE svc/$service_name $port:$port &
        local pf_pid=$!
        sleep 2
        
        if curl -f -s http://localhost:$port/health > /dev/null; then
            kill $pf_pid 2>/dev/null || true
        else
            kill $pf_pid 2>/dev/null || true
            return 1
        fi
    done
    return 0
}

# Test 6: HPA functionality
test_hpa_status() {
    local hpas=$(kubectl get hpa -n $NAMESPACE --no-headers | wc -l)
    [ "$hpas" -eq 5 ] && \
    kubectl get hpa -n $NAMESPACE --no-headers | grep -v "unknown"
}

# Test 7: Network policies
test_network_policies() {
    local netpols=$(kubectl get networkpolicy -n $NAMESPACE --no-headers | wc -l)
    [ "$netpols" -eq 5 ]
}

# Test 8: Secrets exist
test_secrets_exist() {
    local secrets=(
        "mcp-orchestrator-api-secret"
        "mcp-gateway-secret"
        "mcp-policy-proxy-secret"
        "mcp-config-secret"
        "mcp-tracehub-secret"
    )
    
    for secret in "${secrets[@]}"; do
        kubectl get secret -n $NAMESPACE $secret &> /dev/null
        if [ $? -ne 0 ]; then
            return 1
        fi
    done
    return 0
}

# Test 9: External secrets status
test_external_secrets() {
    local external_secrets=$(kubectl get externalsecret -n $NAMESPACE --no-headers | grep "SecretSynced" | wc -l)
    [ "$external_secrets" -eq 5 ]
}

# Test 10: Service monitors
test_service_monitors() {
    local monitors=$(kubectl get servicemonitor -n $NAMESPACE --no-headers | wc -l)
    [ "$monitors" -eq 5 ]
}

# Test 11: Pod disruption budgets
test_pod_disruption_budgets() {
    local pdbs=$(kubectl get pdb -n $NAMESPACE --no-headers | wc -l)
    [ "$pdbs" -eq 5 ]
}

# Test 12: Resource usage within limits
test_resource_usage() {
    # Check if any pod is using more than 80% of requested resources
    kubectl top pods -n $NAMESPACE --no-headers | while read line; do
        local cpu=$(echo $line | awk '{print $2}' | sed 's/m//')
        local memory=$(echo $line | awk '{print $3}' | sed 's/Mi//')
        
        # Check if CPU > 400m (80% of 500m limit)
        if [ "$cpu" -gt 400 ]; then
            return 1
        fi
        
        # Check if memory > 400Mi (80% of 512Mi limit)  
        if [ "$memory" -gt 400 ]; then
            return 1
        fi
    done
}

# Test 13: ArgoCD application status
test_argocd_sync() {
    if kubectl get application -n argocd a1-orchestrator &> /dev/null; then
        local sync_status=$(kubectl get application -n argocd a1-orchestrator -o jsonpath='{.status.sync.status}')
        [ "$sync_status" = "Synced" ]
    else
        log_warning "ArgoCD application not found, skipping sync test"
        return 0
    fi
}

# Test 14: Gatekeeper constraints
test_gatekeeper_constraints() {
    local constraints=$(kubectl get constraints --all-namespaces | grep $NAMESPACE | wc -l)
    [ "$constraints" -gt 0 ]
}

# Test 15: API response time
test_api_response_time() {
    kubectl port-forward -n $NAMESPACE svc/mcp-gateway 8080:8080 &
    local pf_pid=$!
    sleep 2
    
    local start_time=$(date +%s%N)
    curl -f -s http://localhost:8080/health > /dev/null
    local end_time=$(date +%s%N)
    local response_time=$(( (end_time - start_time) / 1000000 ))
    
    kill $pf_pid 2>/dev/null || true
    
    # Response time should be less than 500ms
    [ "$response_time" -lt 500 ]
}

# Performance tests
run_performance_tests() {
    log_info "Running performance tests..."
    
    # Test load balancing
    kubectl port-forward -n $NAMESPACE svc/mcp-gateway 8080:8080 &
    local pf_pid=$!
    sleep 2
    
    local success_count=0
    for i in {1..10}; do
        if curl -f -s http://localhost:8080/health > /dev/null; then
            success_count=$((success_count + 1))
        fi
    done
    
    kill $pf_pid 2>/dev/null || true
    
    if [ "$success_count" -ge 8 ]; then
        log_success "Load balancing test passed (8/10 requests successful)"
    else
        log_error "Load balancing test failed ($success_count/10 requests successful)"
    fi
}

# Security tests
run_security_tests() {
    log_info "Running security tests..."
    
    # Test non-root user
    local non_root_pods=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.securityContext.runAsNonRoot}' | grep -o "true" | wc -l)
    if [ "$non_root_pods" -gt 0 ]; then
        log_success "Security context: Non-root user configured"
    else
        log_warning "Security context: No non-root user configuration found"
    fi
    
    # Test read-only filesystem
    local readonly_pods=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].securityContext.readOnlyRootFilesystem}' | grep -o "true" | wc -l)
    if [ "$readonly_pods" -gt 0 ]; then
        log_success "Security context: Read-only filesystem configured"
    else
        log_warning "Security context: No read-only filesystem configuration found"
    fi
}

# Main execution
main() {
    log_info "Starting A1 Platform Smoke Tests..."
    echo "======================================="
    
    check_prerequisites
    
    # Run all tests
    run_test "Cluster Health" "test_cluster_health"
    run_test "Namespace Exists" "test_namespace_exists"
    run_test "Pods Running" "test_pods_running"
    run_test "Service Endpoints" "test_service_endpoints"
    run_test "Service Health" "test_service_health"
    run_test "HPA Status" "test_hpa_status"
    run_test "Network Policies" "test_network_policies"
    run_test "Secrets Exist" "test_secrets_exist"
    run_test "External Secrets" "test_external_secrets"
    run_test "Service Monitors" "test_service_monitors"
    run_test "Pod Disruption Budgets" "test_pod_disruption_budgets"
    run_test "Resource Usage" "test_resource_usage"
    run_test "ArgoCD Sync" "test_argocd_sync"
    run_test "Gatekeeper Constraints" "test_gatekeeper_constraints"
    run_test "API Response Time" "test_api_response_time"
    
    # Additional tests
    run_performance_tests
    run_security_tests
    
    # Summary
    echo "======================================="
    log_info "Test Summary:"
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    
    if [ "$FAILED_TESTS" -eq 0 ]; then
        log_success "All tests passed! Platform is healthy."
        exit 0
    else
        log_error "$FAILED_TESTS test(s) failed. Please investigate."
        exit 1
    fi
}

# Trap for cleanup
cleanup() {
    log_info "Cleaning up background processes..."
    jobs -p | xargs -r kill 2>/dev/null || true
}

trap cleanup EXIT

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi