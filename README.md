# K3s AI Platform - A1 Orchestrator

A production-ready Kubernetes platform for AI workload orchestration built on K3s with comprehensive security, monitoring, and GitOps automation.

## Repository Structure

```
k3s-ai-platform/
├── infra/                          # Infrastructure automation scripts
│   ├── 01-k3s-install-a1.sh       # K3s installation with security hardening
│   ├── 02-kubeconfig-export.sh    # Kubeconfig management for different access patterns
│   ├── 03-terraform-bootstrap.sh  # Platform component deployment automation
│   └── smoke-tests-a1.sh          # Comprehensive platform health checks
├── terraform/                      # Infrastructure as Code
│   └── platform/                  # Platform bootstrap configuration
│       ├── providers.tf           # Terraform providers (Kubernetes, Helm)
│       ├── main.tf                # Platform components (ArgoCD, Gatekeeper, etc.)
│       ├── variables.tf           # Configuration variables
│       ├── outputs.tf             # Infrastructure outputs
│       └── values/                # Helm values for platform components
├── apps/                          # Application deployments
│   ├── root-app/                  # ArgoCD App-of-Apps pattern
│   │   └── app-of-apps.yaml      # Root application managing all services
│   └── a1-orchestrator/          # AI orchestrator services
│       ├── kustomization.yaml    # Main kustomization file
│       ├── namespace.yaml        # Namespace definition
│       └── mcp-*/                # Individual microservices with complete manifests
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── horizontalpodautoscaler.yaml
│           ├── networkpolicy.yaml
│           ├── poddisruptionbudget.yaml
│           ├── servicemonitor.yaml
│           └── externalsecret.yaml
├── policies/                     # Security and governance policies
│   └── gatekeeper-constraints.yaml # OPA Gatekeeper policy constraints
├── dashboards/                   # Monitoring dashboards
│   └── a1-orchestrator-grafana.json # Grafana dashboard for platform monitoring
└── docs/                        # Documentation
    ├── a1-architecture.md       # Platform architecture documentation
    ├── runbook-a1.md           # Operations runbook
    └── smoke-tests-a1.md       # Testing documentation
```

## 🚀 Quick Start

### Prerequisites
- Linux system with 16GB RAM, 8 vCPU minimum
- Root or sudo access
- Internet connectivity

### Installation

1. **Install K3s cluster:**
   ```bash
   sudo ./infra/01-k3s-install-a1.sh
   ```

2. **Export kubeconfig:**
   ```bash
   ./infra/02-kubeconfig-export.sh
   export KUBECONFIG=$HOME/.kube/config
   ```

3. **Bootstrap platform components:**
   ```bash
   ./infra/03-terraform-bootstrap.sh
   ```

4. **Deploy applications:**
   ```bash
   kubectl apply -f apps/root-app/app-of-apps.yaml
   ```

5. **Run health checks:**
   ```bash
   ./infra/smoke-tests-a1.sh
   ```

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        A1 AI Orchestrator Platform             │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   mcp-gateway   │  │ mcp-orchestrator │  │ mcp-policy-proxy│ │
│  │   (Entry Point) │◄─┤      -api        ├─►│   (Security)    │ │
│  │                 │  │   (Core Logic)   │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│           │                     │                     │        │
│           ▼                     ▼                     ▼        │
│  ┌─────────────────┐  ┌─────────────────┐                     │
│  │   mcp-config    │  │  mcp-tracehub   │                     │
│  │ (Configuration) │  │   (Tracing)     │                     │
│  └─────────────────┘  └─────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
```

## Platform Components

### Infrastructure Layer
- **K3s v1.30.5+k3s1**: Lightweight Kubernetes distribution
- **Security Hardening**: Kernel parameters, audit logging, firewall configuration
- **Single-node Configuration**: Optimized for A1 hardware specifications

### Platform Services
- **ArgoCD**: GitOps continuous deployment and application management
- **OPA Gatekeeper v3.14.0**: Policy enforcement and compliance validation
- **External Secrets Operator**: Secure secret management integration
- **KEDA**: Event-driven horizontal pod autoscaling
- **Prometheus Stack**: Comprehensive monitoring and alerting

### Application Services
- **mcp-orchestrator-api**: Core AI workflow orchestration engine
- **mcp-gateway**: API gateway with load balancing and security
- **mcp-policy-proxy**: Policy enforcement and compliance validation
- **mcp-config**: Centralized configuration management
- **mcp-tracehub**: Distributed tracing and observability

## 🔐 Security Features

- **Network Policies**: Pod-to-pod communication control with default deny-all
- **Pod Security Standards**: Security context enforcement via Gatekeeper
- **Resource Quotas**: CPU and memory limits for all services
- **Image Security**: Tag restrictions and vulnerability scanning
- **Secret Management**: External secret store integration with 15-minute refresh
- **RBAC**: Role-based access control for service accounts
- **Audit Logging**: Comprehensive Kubernetes audit trail

## 📊 Observability

### Monitoring Stack
- **Prometheus**: Metrics collection with custom business KPIs
- **Grafana**: Real-time dashboards for platform and service health
- **ServiceMonitor**: Automatic Prometheus target discovery
- **AlertManager**: Intelligent alerting with escalation policies

### Key Metrics
- **Request Rate**: Requests per second across all services
- **Error Rate**: 4xx/5xx error percentages with SLA tracking
- **P95 Latency**: Response time percentiles for performance monitoring
- **Resource Usage**: CPU, memory, and network I/O utilization
- **HPA Status**: Autoscaling behavior and pod count tracking

### Tracing
- **Distributed Tracing**: End-to-end request flow analysis
- **Jaeger Integration**: Performance profiling and bottleneck identification
- **Correlation IDs**: Request tracking across service boundaries

## ⚡ Autoscaling

### Horizontal Pod Autoscaling (HPA)
- **CPU-based Scaling**: Target 70% CPU utilization
- **Memory-based Scaling**: Target 80% memory utilization
- **Custom Metrics**: KEDA integration for business metric scaling
- **Scale Parameters**: Min 2, Max 10 replicas per service

### Resource Management
- **Resource Requests**: Guaranteed CPU and memory allocation
- **Resource Limits**: Hard limits to prevent resource exhaustion
- **Pod Disruption Budgets**: Maintain minimum availability during disruptions
- **Quality of Service**: Guaranteed QoS class for critical services

## 🛠️ Operations

### Monitoring Access
```bash
# Grafana Dashboard
kubectl port-forward -n prometheus svc/grafana 3000:80
# Access: http://localhost:3000

# Prometheus Metrics
kubectl port-forward -n prometheus svc/prometheus 9090:9090
# Access: http://localhost:9090

# ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:80
# Access: https://localhost:8080
```

### Common Operations
```bash
# Check service status
kubectl get pods -n a1-orchestrator

# View service logs
kubectl logs -n a1-orchestrator deployment/mcp-gateway -f

# Scale service manually
kubectl scale deployment/mcp-gateway --replicas=3 -n a1-orchestrator

# Run health checks
./infra/smoke-tests-a1.sh

# Sync ArgoCD applications
kubectl patch app a1-orchestrator -n argocd -p '{"operation":{"sync":{}}}' --type merge
```

### Troubleshooting
```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A

# Check resource usage
kubectl top pods -n a1-orchestrator
kubectl top nodes

# Check events for issues
kubectl get events -n a1-orchestrator --sort-by='.lastTimestamp'

# Check HPA status
kubectl describe hpa -n a1-orchestrator

# Check network policies
kubectl describe networkpolicy -n a1-orchestrator
```

## 📚 Documentation

- **[Architecture Guide](docs/a1-architecture.md)**: Detailed platform architecture and design decisions
- **[Operations Runbook](docs/runbook-a1.md)**: Day-to-day operations, incident response, and maintenance procedures
- **[Testing Guide](docs/smoke-tests-a1.md)**: Comprehensive testing procedures and validation steps

## 🔧 Configuration

### Infrastructure Configuration
- **K3s Settings**: Located in `infra/01-k3s-install-a1.sh`
- **Platform Components**: Configured via Terraform in `terraform/platform/`
- **Helm Values**: Service-specific configurations in `terraform/platform/values/`

### Application Configuration
- **Service Deployments**: Individual service manifests in `apps/a1-orchestrator/mcp-*/`
- **Kustomization**: Overlay configurations for environment-specific settings
- **Secret Management**: External secret definitions in `externalsecret.yaml` files

### Security Configuration
- **Network Policies**: Service-to-service communication rules
- **Gatekeeper Constraints**: Policy enforcement rules in `policies/`
- **RBAC**: Role-based access control in service manifests

## 🚦 Health Checks

The platform includes comprehensive health monitoring:

### Automated Health Checks
```bash
# Run full platform health validation
./infra/smoke-tests-a1.sh

# Check individual service health
kubectl get pods -n a1-orchestrator
kubectl get svc -n a1-orchestrator
kubectl get hpa -n a1-orchestrator
```

### Service Health Endpoints
- **Health Checks**: All services expose `/health` endpoints
- **Readiness Probes**: Kubernetes readiness validation
- **Liveness Probes**: Automatic pod restart on failure

### Monitoring Integration
- **ServiceMonitor**: Automatic Prometheus scraping configuration
- **Grafana Dashboards**: Pre-configured platform monitoring views
- **Alert Rules**: Proactive alerting on critical metrics

## 📈 Performance Characteristics

### Capacity Limits
- **Maximum Pods**: 50 per node (K3s single-node limit)
- **Request Rate**: 1000 requests/second target capacity
- **Concurrent Users**: 500 active connections
- **Data Processing**: 100MB/second throughput

### SLA Targets
- **Availability**: 99.9% uptime (8.77 hours/year downtime)
- **P95 Latency**: < 500ms for API responses
- **P99 Latency**: < 1000ms for complex operations
- **Error Rate**: < 1% under normal load conditions

## 🔄 Development Workflow

### GitOps Pattern
1. **Code Changes**: Developers push changes to Git repository
2. **ArgoCD Sync**: Automatic detection and deployment of changes
3. **Health Validation**: Automated health checks post-deployment
4. **Monitoring**: Real-time observability and alerting

### Service Development
1. **Local Development**: Port-forwarding for local testing
2. **Container Build**: Build and push to container registry
3. **Manifest Updates**: Update Kubernetes manifests and configurations
4. **GitOps Deployment**: Automated deployment via ArgoCD

### Testing Strategy
- **Unit Tests**: Individual service testing
- **Integration Tests**: Cross-service communication validation
- **Smoke Tests**: End-to-end platform health validation
- **Performance Tests**: Load testing and capacity validation

## 🤝 Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/new-feature`
3. **Make changes and test**: Run smoke tests to validate changes
4. **Commit changes**: `git commit -am 'Add new feature'`
5. **Push to branch**: `git push origin feature/new-feature`
6. **Create Pull Request**: Submit for review and validation

### Development Guidelines
- Follow Kubernetes best practices for manifest creation
- Include comprehensive testing for new features
- Update documentation for any architectural changes
- Ensure security compliance with existing policies

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

### Escalation Path
1. **Platform Engineer**: First level support (15 min response)
2. **Senior Platform Engineer**: Second level support (30 min response)
3. **Platform Architect**: Third level support (1 hour response)
4. **Emergency Escalation**: Critical issues (immediate response)

### Getting Help
- **Documentation**: Check the `docs/` directory for detailed guides
- **Health Checks**: Run `./infra/smoke-tests-a1.sh` for platform validation
- **Logs**: Use `kubectl logs` for service-specific debugging
- **Monitoring**: Access Grafana dashboards for performance insights