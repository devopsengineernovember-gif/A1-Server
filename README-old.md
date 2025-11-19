# K3s AI Platform - Production Ready

Production-ready single-node K3s cluster with Terraform-managed platform add-ons and ArgoCD-deployed AI agents.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    A1 Node (16GB/8vCPU)                     │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐                 │
│  │   K3s Control   │  │  Platform Add-  │                 │
│  │     Plane       │  │     ons         │                 │
│  │                 │  │                 │                 │
│  │ • API Server    │  │ • ArgoCD        │                 │
│  │ • etcd          │  │ • Gatekeeper    │                 │
│  │ • Controller    │  │ • External Sec  │                 │
│  │ • Scheduler     │  │ • KEDA          │                 │
│  │                 │  │ • Prometheus    │                 │
│  └─────────────────┘  └─────────────────┘                 │
│                                                             │
│  ┌─────────────────────────────────────────────────────────│
│  │              A1 AI Orchestrator                        │
│  │                                                        │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │ │mcp-orchestr-│ │ mcp-gateway │ │mcp-policy-  │       │
│  │ │   ator-api  │ │             │ │   proxy     │       │
│  │ │             │ │             │ │             │       │
│  │ │ (Public API)│ │(Routing/    │ │(OPA Pre/    │       │
│  │ │             │ │ Planning)   │ │Post Checks) │       │
│  │ └─────────────┘ └─────────────┘ └─────────────┘       │
│  │                                                        │
│  │ ┌─────────────┐ ┌─────────────┐                      │
│  │ │ mcp-config  │ │mcp-tracehub │                      │
│  │ │             │ │             │                      │
│  │ │(Effective   │ │(Tracing/    │                      │
│  │ │ Config)     │ │Correlation) │                      │
│  │ └─────────────┘ └─────────────┘                      │
│  └─────────────────────────────────────────────────────────│
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### 1. Install K3s
```bash
./scripts/install-k3s.sh
```

### 2. Bootstrap Platform
```bash
cd terraform
terraform init
terraform apply
```

### 3. Deploy AI Agents
```bash
# ArgoCD will automatically deploy the root app
# Access ArgoCD UI: https://argocd.a1.local
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 📁 Repository Structure

```
k3s-ai-platform/
├── README.md
├── scripts/
│   ├── install-k3s.sh              # K3s installation script
│   └── uninstall.sh                # Cleanup script
├── terraform/
│   ├── main.tf                     # Platform add-ons (ArgoCD, etc.)
│   ├── variables.tf                # Configuration variables
│   ├── terraform.tfvars            # Environment values
│   └── versions.tf                 # Provider versions
├── k8s-manifests/
│   ├── root-app/                   # ArgoCD App-of-Apps
│   │   └── application.yaml
│   ├── a1-orchestrator/            # A1 AI Agent Services
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── networkpolicy.yaml
│   │   ├── external-secrets.yaml
│   │   ├── services/
│   │   │   ├── mcp-orchestrator-api/
│   │   │   ├── mcp-gateway/
│   │   │   ├── mcp-policy-proxy/
│   │   │   ├── mcp-config/
│   │   │   └── mcp-tracehub/
│   │   └── monitoring/
│   │       ├── servicemonitor.yaml
│   │       └── grafana-dashboard.json
│   └── platform/
│       ├── gatekeeper-policies/
│       └── monitoring-config/
└── docs/
    ├── SECURITY.md
    ├── OPERATIONS.md
    └── TROUBLESHOOTING.md
```

## 🔐 Security Features

- **NetworkPolicy**: Default deny-all with specific allow rules
- **Pod Security**: Non-root user, read-only root filesystem
- **Resource Limits**: CPU/Memory limits for all services
- **Image Security**: Pinned image tags, vulnerability scanning
- **mTLS**: Inter-service communication encryption
- **OIDC**: Authentication via external identity provider
- **Secrets Management**: External Secrets Operator (no secrets in Git)
- **OPA Gatekeeper**: Policy enforcement at admission

## 📊 Observability

- **Metrics**: Prometheus scraping with ServiceMonitor
- **Dashboards**: Grafana dashboard for A1 orchestrator
- **Logs**: Loki log aggregation
- **Tracing**: Distributed tracing via mcp-tracehub
- **Alerts**: PrometheusRule for critical events

## ⚡ Autoscaling

- **KEDA**: Custom metrics autoscaling (RPS, p95 latency)
- **HPA**: CPU-based fallback scaling
- **VPA**: Vertical resource optimization (optional)

## 🛠️ Operations

### Monitor Services
```bash
# Check all services
kubectl get pods -n a1-orchestrator

# View logs
kubectl logs -n a1-orchestrator -l app=mcp-orchestrator-api

# Check metrics
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
```

### Scale Services
```bash
# Manual scaling
kubectl scale deployment mcp-orchestrator-api -n a1-orchestrator --replicas=3

# Check autoscaling
kubectl get hpa -n a1-orchestrator
kubectl get scaledobject -n a1-orchestrator
```

### Update Configuration
```bash
# Update via Git
git commit -am "Update config"
git push
# ArgoCD will auto-sync changes
```

## 🔧 Configuration

Key configuration files:
- `terraform/terraform.tfvars` - Platform settings
- `k8s-manifests/a1-orchestrator/services/*/config.yaml` - Service configs
- `k8s-manifests/platform/gatekeeper-policies/` - Security policies

## 📚 Documentation

- [Security Guide](docs/SECURITY.md) - Security configuration and best practices
- [Operations Guide](docs/OPERATIONS.md) - Day-to-day operations
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions

## 🏷️ Version Info

- K3s: v1.28.4+k3s1
- ArgoCD: v2.9.3
- OPA Gatekeeper: v3.14.0
- External Secrets: v0.9.11
- KEDA: v2.12.1
- Prometheus Stack: v55.5.0

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push branch (`git push origin feature/amazing-feature`)
5. Create Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.