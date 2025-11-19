# DEPLOYMENT_GUIDE.md

Comprehensive deployment and validation guide for the K3s AI Platform.

## 🚀 Complete Deployment Guide

### Prerequisites Checklist
- [ ] Single node with minimum 16GB RAM, 8 vCPUs
- [ ] Ubuntu 20.04+ or CentOS 8+
- [ ] Root/sudo access
- [ ] Internet connectivity for image pulls
- [ ] Git and basic CLI tools installed

### Phase 1: K3s Installation

#### 1.1 Install K3s Cluster
```bash
# Make script executable and run
cd k3s-ai-platform/scripts/
chmod +x install-k3s.sh
sudo ./install-k3s.sh

# Verify installation
kubectl get nodes
kubectl get pods -A
```

#### 1.2 Validation Checks
```bash
# Check K3s service status
sudo systemctl status k3s

# Verify cluster info
kubectl cluster-info

# Check node readiness
kubectl describe node $(hostname)

# Verify default storage class
kubectl get storageclass
```

### Phase 2: Platform Bootstrap with Terraform

#### 2.1 Initialize Terraform
```bash
cd terraform/
terraform init
terraform validate
terraform plan
```

#### 2.2 Deploy Platform Components
```bash
# Apply infrastructure
terraform apply

# Verify platform services are running
kubectl get pods -n argocd
kubectl get pods -n gatekeeper-system  
kubectl get pods -n external-secrets
kubectl get pods -n keda
kubectl get pods -n monitoring
```

#### 2.3 Platform Component Validation
```bash
# ArgoCD ready check
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

# Gatekeeper ready check  
kubectl wait --for=condition=Available deployment/gatekeeper-controller-manager -n gatekeeper-system --timeout=300s

# External Secrets ready check
kubectl wait --for=condition=Available deployment/external-secrets -n external-secrets --timeout=300s

# KEDA ready check
kubectl wait --for=condition=Available deployment/keda-operator -n keda --timeout=300s

# Prometheus ready check
kubectl wait --for=condition=Available deployment/prometheus-operator-kube-p-operator -n monitoring --timeout=300s
```

### Phase 3: AI Orchestrator Deployment

#### 3.1 ArgoCD Access Setup
```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Port forward ArgoCD UI (run in separate terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at https://localhost:8080
# Username: admin, Password: <from above command>
```

#### 3.2 Deploy Root Application
```bash
# Apply the root ArgoCD application
kubectl apply -f k8s-manifests/a1-orchestrator/root-app.yaml

# Verify root app creation
kubectl get application -n argocd
kubectl describe application a1-orchestrator-root -n argocd
```

#### 3.3 Monitor Application Sync
```bash
# Watch ArgoCD application status
watch kubectl get applications -n argocd

# Check sync status
argocd app sync a1-orchestrator-root --server localhost:8080

# View detailed sync status
argocd app get a1-orchestrator-root --server localhost:8080
```

### Phase 4: Service Validation

#### 4.1 Namespace and Basic Resources
```bash
# Verify namespace creation
kubectl get namespace a1-orchestrator

# Check NetworkPolicies
kubectl get networkpolicy -n a1-orchestrator

# Verify External Secrets
kubectl get externalsecrets -n a1-orchestrator
kubectl get secretstore -n a1-orchestrator
```

#### 4.2 A1 Orchestrator Services
```bash
# Check all service deployments
kubectl get deployments -n a1-orchestrator

# Verify all pods are running
kubectl get pods -n a1-orchestrator

# Check service endpoints
kubectl get services -n a1-orchestrator

# Validate service accounts and RBAC
kubectl get serviceaccounts -n a1-orchestrator
kubectl get clusterroles | grep mcp-
kubectl get clusterrolebindings | grep mcp-
```

#### 4.3 Individual Service Health
```bash
# mcp-orchestrator-api
kubectl logs deployment/mcp-orchestrator-api -n a1-orchestrator --tail=50
kubectl port-forward svc/mcp-orchestrator-api -n a1-orchestrator 8081:8080

# mcp-gateway  
kubectl logs deployment/mcp-gateway -n a1-orchestrator --tail=50
kubectl port-forward svc/mcp-gateway -n a1-orchestrator 8082:8080

# mcp-policy-proxy
kubectl logs deployment/mcp-policy-proxy -n a1-orchestrator --tail=50
kubectl port-forward svc/mcp-policy-proxy -n a1-orchestrator 8083:8080

# mcp-config
kubectl logs deployment/mcp-config -n a1-orchestrator --tail=50  
kubectl port-forward svc/mcp-config -n a1-orchestrator 8084:8080

# mcp-tracehub
kubectl logs deployment/mcp-tracehub -n a1-orchestrator --tail=50
kubectl port-forward svc/mcp-tracehub -n a1-orchestrator 8085:8080
```

### Phase 5: Monitoring and Observability

#### 5.1 Prometheus Setup Validation
```bash
# Check Prometheus pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Port forward Prometheus UI
kubectl port-forward svc/prometheus-operated -n monitoring 9090:9090
# Access at http://localhost:9090

# Verify ServiceMonitor discovery
kubectl get servicemonitor -n a1-orchestrator
kubectl get servicemonitor -n monitoring
```

#### 5.2 Grafana Dashboard Access
```bash
# Get Grafana admin password
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode; echo

# Port forward Grafana UI
kubectl port-forward svc/grafana -n monitoring 3000:80
# Access at http://localhost:3000
# Username: admin, Password: <from above command>
```

#### 5.3 Validate Metrics Collection
```bash
# Check if metrics are being scraped
curl -s http://localhost:9090/api/v1/query?query=up{namespace="a1-orchestrator"}

# Verify custom metrics availability
curl -s http://localhost:9090/api/v1/query?query=http_requests_total{namespace="a1-orchestrator"}

# Check alert rules
kubectl get prometheusrule -n a1-orchestrator
```

### Phase 6: Autoscaling Validation

#### 6.1 HPA Status Check
```bash
# Check all HPAs
kubectl get hpa -n a1-orchestrator

# Detailed HPA status
kubectl describe hpa -n a1-orchestrator

# Watch HPA scaling behavior
watch kubectl get hpa -n a1-orchestrator
```

#### 6.2 KEDA ScaledObjects
```bash
# Check KEDA ScaledObjects
kubectl get scaledobjects -n a1-orchestrator

# Describe ScaledObjects for details
kubectl describe scaledobject -n a1-orchestrator

# Check KEDA operator logs
kubectl logs deployment/keda-operator -n keda
```

#### 6.3 Scaling Test
```bash
# Generate load to test scaling
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh

# Inside the load generator pod:
while true; do 
  wget -q -O- http://mcp-orchestrator-api.a1-orchestrator:8080/health
  sleep 0.1
done

# In another terminal, watch scaling
watch kubectl get pods -n a1-orchestrator
watch kubectl get hpa -n a1-orchestrator
```

### Phase 7: Security Validation

#### 7.1 Network Policy Testing
```bash
# Test that default-deny is working
kubectl run test-pod --image=busybox -n a1-orchestrator --rm -it -- /bin/sh

# Inside test pod - this should fail (blocked by NetworkPolicy):
wget -q --timeout=5 -O- http://mcp-gateway.a1-orchestrator:8080/health

# Test allowed communication works
kubectl exec deployment/mcp-orchestrator-api -n a1-orchestrator -- \
  curl -s http://mcp-config.a1-orchestrator:8080/health
```

#### 7.2 OPA Gatekeeper Policy Validation
```bash
# Check constraint templates
kubectl get constrainttemplates

# View active constraints  
kubectl get constraints

# Test policy enforcement - try creating privileged pod (should fail)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-test
  namespace: a1-orchestrator
spec:
  containers:
  - name: test
    image: busybox
    securityContext:
      privileged: true
EOF
```

#### 7.3 Secret Management Validation
```bash
# Verify External Secrets are synced
kubectl get externalsecrets -n a1-orchestrator
kubectl describe externalsecret orchestrator-config -n a1-orchestrator

# Check that secrets exist
kubectl get secrets -n a1-orchestrator

# Verify secret content (should be base64 encoded)
kubectl get secret orchestrator-config -n a1-orchestrator -o yaml
```

### Phase 8: End-to-End Testing

#### 8.1 Full Service Test
```bash
# Test orchestrator API health endpoint
curl -k https://localhost:8081/health

# Test configuration service
curl -k https://localhost:8084/config/health

# Test tracing hub
curl -k https://localhost:8085/health
```

#### 8.2 Load Testing
```bash
# Install hey load testing tool
go install github.com/rakyll/hey@latest

# Test orchestrator API under load
hey -n 1000 -c 10 -m GET https://localhost:8081/api/v1/health

# Monitor scaling response
kubectl get hpa -n a1-orchestrator -w
```

#### 8.3 Failover Testing
```bash
# Kill a pod and watch recovery
kubectl delete pod -l app.kubernetes.io/name=mcp-orchestrator-api -n a1-orchestrator

# Watch pod recreation
kubectl get pods -n a1-orchestrator -w

# Verify service continues working
for i in {1..10}; do 
  curl -k https://localhost:8081/health
  sleep 2
done
```

## 🔧 Configuration Validation

### Terraform Configuration
```bash
# Validate terraform configuration
cd terraform/
terraform validate
terraform fmt -check
terraform plan -detailed-exitcode
```

### Kubernetes Manifests
```bash
# Validate all YAML files
find k8s-manifests/ -name "*.yaml" -exec kubectl apply --dry-run=client -f {} \;

# Check for YAML syntax
find k8s-manifests/ -name "*.yaml" -exec yaml-validate {} \;
```

## 📊 Monitoring Validation

### Key Metrics to Monitor
```bash
# Service availability (should be 1)
curl -s http://localhost:9090/api/v1/query?query=up{namespace=\"a1-orchestrator\"}

# HTTP request rate
curl -s http://localhost:9090/api/v1/query?query=rate(http_requests_total{namespace=\"a1-orchestrator\"}[5m])

# Error rate (should be low)
curl -s http://localhost:9090/api/v1/query?query=rate(http_requests_total{namespace=\"a1-orchestrator\",status=~\"5..\"}[5m])

# Resource utilization
curl -s http://localhost:9090/api/v1/query?query=container_memory_working_set_bytes{namespace=\"a1-orchestrator\"}
```

### Dashboard Verification
1. Access Grafana at http://localhost:3000
2. Navigate to "A1 AI Orchestrator" dashboard
3. Verify all panels are populated with data
4. Check that alerts are configured and firing appropriately

## 🚨 Troubleshooting Common Issues

### ArgoCD App Not Syncing
```bash
# Check ArgoCD server logs
kubectl logs deployment/argocd-server -n argocd

# Force sync application
argocd app sync a1-orchestrator-root --force

# Check Git repository access
argocd repo list
```

### Pod CrashLoopBackOff
```bash
# Check pod events
kubectl describe pod <pod-name> -n a1-orchestrator

# Check container logs
kubectl logs <pod-name> -n a1-orchestrator --previous

# Check resource constraints
kubectl top pods -n a1-orchestrator
```

### Secrets Not Available
```bash
# Check External Secrets operator logs
kubectl logs deployment/external-secrets -n external-secrets

# Verify SecretStore configuration
kubectl describe secretstore vault-backend -n a1-orchestrator

# Check External Secret status
kubectl describe externalsecret orchestrator-config -n a1-orchestrator
```

### Network Connectivity Issues
```bash
# Test DNS resolution
kubectl run -i --tty --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check NetworkPolicy rules
kubectl describe networkpolicy -n a1-orchestrator

# Test service connectivity
kubectl run -i --tty --rm debug --image=nicolaka/netshoot --restart=Never -- /bin/bash
```

## ✅ Deployment Checklist

### Pre-Deployment
- [ ] Hardware requirements met (16GB RAM, 8 vCPUs)
- [ ] Operating system compatible (Ubuntu 20.04+)
- [ ] Network connectivity verified
- [ ] Required permissions (root/sudo)

### K3s Installation
- [ ] K3s service running and healthy
- [ ] Node in Ready state
- [ ] Default storage class available
- [ ] Basic networking functional

### Platform Bootstrap  
- [ ] ArgoCD accessible and healthy
- [ ] Gatekeeper policies installed
- [ ] External Secrets operator functional
- [ ] KEDA operator running
- [ ] Prometheus stack deployed

### A1 Orchestrator Services
- [ ] All 5 services deployed (api, gateway, policy-proxy, config, tracehub)
- [ ] All pods in Running state
- [ ] Services accessible internally
- [ ] Health checks passing
- [ ] Metrics being collected

### Security & Policies
- [ ] NetworkPolicies enforced
- [ ] OPA Gatekeeper constraints active
- [ ] Pod security contexts applied
- [ ] External secrets synced
- [ ] mTLS certificates deployed

### Monitoring & Observability
- [ ] Prometheus scraping metrics
- [ ] Grafana dashboards populated
- [ ] Alert rules configured
- [ ] Log aggregation functional
- [ ] Distributed tracing working

### Autoscaling
- [ ] HPA configured for all services
- [ ] KEDA ScaledObjects active
- [ ] Custom metrics available
- [ ] Scaling tests passing

### End-to-End Validation
- [ ] Load testing successful
- [ ] Failover testing passed
- [ ] Performance within SLAs
- [ ] Security validation complete

## 📞 Support & Maintenance

### Regular Health Checks
```bash
# Daily health check script
#!/bin/bash
echo "=== K3s AI Platform Health Check ==="
kubectl get nodes
kubectl get pods -n a1-orchestrator
kubectl get hpa -n a1-orchestrator
kubectl get externalsecrets -n a1-orchestrator
kubectl top pods -n a1-orchestrator
```

### Update Procedures
```bash
# Update platform via Git
git pull origin main
cd terraform/
terraform plan
terraform apply

# ArgoCD will auto-sync applications
argocd app sync a1-orchestrator-root
```

### Backup Procedures
```bash
# Backup cluster state
kubectl get all -n a1-orchestrator -o yaml > a1-orchestrator-backup.yaml

# Backup persistent data
kubectl exec -n a1-orchestrator deployment/mcp-config -- tar -czf /tmp/config-backup.tar.gz /data
kubectl cp a1-orchestrator/$(kubectl get pod -l app.kubernetes.io/name=mcp-config -o name | head -1 | cut -d'/' -f2):/tmp/config-backup.tar.gz ./config-backup.tar.gz
```

This comprehensive deployment guide ensures a successful, validated K3s AI Platform deployment with full production readiness.