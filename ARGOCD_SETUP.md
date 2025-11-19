# ArgoCD Repository Setup Guide

This guide explains how to add your GitHub repository to ArgoCD for GitOps deployment.

## 🔗 Repository Information

- **Repository URL**: `https://github.com/devopsengineernovember-gif/k3s-ai-platform.git`
- **Branch**: `main`
- **Apps Path**: `apps/`

## 🚀 Adding Repository to ArgoCD

### Option 1: Using ArgoCD CLI

```bash
# Install ArgoCD CLI (if not already installed)
curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 /tmp/argocd /usr/local/bin/argocd

# Login to ArgoCD
argocd login localhost:8080 --insecure

# Add repository
argocd repo add https://github.com/devopsengineernovember-gif/k3s-ai-platform.git \
  --type git \
  --name k3s-ai-platform
```

### Option 2: Using ArgoCD Web UI

1. **Access ArgoCD UI**:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   Open https://localhost:8080

2. **Login**:
   - Username: `admin`
   - Password: Get with `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

3. **Add Repository**:
   - Go to Settings → Repositories
   - Click "Connect Repo using HTTPS"
   - Repository URL: `https://github.com/devopsengineernovember-gif/k3s-ai-platform.git`
   - Click "Connect"

### Option 3: Using Kubernetes Manifest

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: k3s-ai-platform-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/devopsengineernovember-gif/k3s-ai-platform.git
EOF
```

## 📱 Deploy Applications

### 1. Deploy Root Application (App-of-Apps)

```bash
kubectl apply -f apps/root-app/app-of-apps.yaml
```

### 2. Verify Deployment

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check application status
argocd app get root-app
argocd app get a1-orchestrator

# Check deployed services
kubectl get pods -n a1-orchestrator
```

## 🔄 Automatic Sync Configuration

Your repository is configured for automatic synchronization:

- **Auto-Sync**: Enabled with 3-second polling
- **Auto-Prune**: Removes orphaned resources
- **Self-Heal**: Corrects configuration drift
- **Create Namespace**: Auto-creates target namespaces

### Manual Sync (if needed)

```bash
# Sync all applications
argocd app sync root-app
argocd app sync a1-orchestrator

# Force sync (if out of sync)
argocd app sync root-app --force
```

## 🔍 Monitoring ArgoCD Applications

### Check Application Health

```bash
# Get application status
argocd app list

# Get detailed application info
argocd app get a1-orchestrator

# View application logs
argocd app logs a1-orchestrator
```

### ArgoCD Dashboard

Access the ArgoCD dashboard to monitor:
- Application sync status
- Resource health
- Sync history
- Application topology

## 🐛 Troubleshooting

### Common Issues

1. **Repository Connection Failed**:
   ```bash
   # Check repository credentials
   argocd repo list
   
   # Test repository access
   git ls-remote https://github.com/devopsengineernovember-gif/k3s-ai-platform.git
   ```

2. **Application Sync Failed**:
   ```bash
   # Check application details
   argocd app get a1-orchestrator
   
   # View sync errors
   argocd app sync a1-orchestrator --dry-run
   ```

3. **Resource Health Issues**:
   ```bash
   # Check Kubernetes events
   kubectl get events -n a1-orchestrator
   
   # Check pod status
   kubectl describe pods -n a1-orchestrator
   ```

### Refresh Repository Cache

```bash
# Refresh repository to detect latest changes
argocd app sync root-app --refresh
```

## 📋 Next Steps

1. **Push to GitHub**: Push your local repository to GitHub
2. **Add Repository**: Add the repository to ArgoCD using one of the methods above
3. **Deploy Applications**: Apply the root application manifest
4. **Monitor**: Use ArgoCD dashboard to monitor deployments
5. **Validate**: Run health checks to ensure everything is working

## 🔗 Useful Commands

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Check ArgoCD server status
kubectl get pods -n argocd

# View ArgoCD applications
kubectl get applications -n argocd

# Sync application manually
kubectl patch app a1-orchestrator -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"force":true}}}}'
```