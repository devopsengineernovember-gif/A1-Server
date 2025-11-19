# A1 Platform Operations Runbook

## Emergency Contacts

- **Platform Team**: platform-team@company.com
- **On-call**: +1-555-ONCALL
- **Escalation**: platform-lead@company.com

## Quick Reference

### Cluster Access
```bash
# Export kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Check cluster status
kubectl get nodes
kubectl get pods -A
```

### Common Commands
```bash
# Check service health
kubectl get pods -n a1-orchestrator
kubectl get svc -n a1-orchestrator

# View logs
kubectl logs -n a1-orchestrator deployment/mcp-gateway
kubectl logs -n a1-orchestrator deployment/mcp-orchestrator-api

# Port forward for debugging
kubectl port-forward -n a1-orchestrator svc/mcp-gateway 8080:8080
```

## Incident Response Procedures

### Service Down Alert

#### 1. Immediate Assessment
```bash
# Check pod status
kubectl get pods -n a1-orchestrator

# Check recent events
kubectl get events -n a1-orchestrator --sort-by='.lastTimestamp'

# Check resource usage
kubectl top pods -n a1-orchestrator
```

#### 2. Service Recovery
```bash
# Restart deployment
kubectl rollout restart deployment/mcp-gateway -n a1-orchestrator

# Scale up replicas
kubectl scale deployment/mcp-gateway --replicas=3 -n a1-orchestrator

# Force pod recreation
kubectl delete pod -l app=mcp-gateway -n a1-orchestrator
```

### High Memory Usage Alert

#### 1. Investigation
```bash
# Check memory usage
kubectl top pods -n a1-orchestrator
kubectl describe pod <pod-name> -n a1-orchestrator

# Check for memory leaks
kubectl logs -n a1-orchestrator <pod-name> --previous
```

#### 2. Mitigation
```bash
# Temporary scale up
kubectl scale deployment/<service> --replicas=5 -n a1-orchestrator

# Update resource limits
kubectl patch deployment/<service> -n a1-orchestrator -p '{"spec":{"template":{"spec":{"containers":[{"name":"<container>","resources":{"limits":{"memory":"1Gi"}}}]}}}}'
```

### High CPU Usage Alert

#### 1. Investigation
```bash
# Check CPU usage
kubectl top pods -n a1-orchestrator
kubectl describe hpa -n a1-orchestrator

# Check autoscaling status
kubectl get hpa -n a1-orchestrator
```

#### 2. Mitigation
```bash
# Manual scale if HPA is not responding
kubectl scale deployment/<service> --replicas=8 -n a1-orchestrator

# Check HPA configuration
kubectl describe hpa <service>-hpa -n a1-orchestrator
```

## Maintenance Procedures

### Planned Deployment

#### 1. Pre-deployment Checks
```bash
# Verify cluster health
./infra/smoke-tests-a1.sh

# Check ArgoCD status
kubectl get applications -n argocd

# Verify resource availability
kubectl describe nodes
```

#### 2. Deployment Process
```bash
# Sync ArgoCD application
argocd app sync a1-orchestrator

# Monitor deployment
kubectl rollout status deployment/<service> -n a1-orchestrator

# Verify health checks
kubectl get pods -n a1-orchestrator -w
```

#### 3. Post-deployment Validation
```bash
# Run smoke tests
./infra/smoke-tests-a1.sh

# Check service endpoints
curl http://localhost:8080/health

# Monitor metrics
kubectl port-forward -n prometheus svc/prometheus 9090:9090
```

### Certificate Rotation

#### 1. Check Certificate Status
```bash
# Check TLS secrets
kubectl get secrets -n a1-orchestrator | grep tls

# Check certificate expiration
kubectl get secret <tls-secret> -n a1-orchestrator -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

#### 2. Rotate Certificates
```bash
# Trigger External Secrets refresh
kubectl annotate externalsecret <secret-name> -n a1-orchestrator force-sync="$(date)"

# Restart affected services
kubectl rollout restart deployment/mcp-gateway -n a1-orchestrator
```

## Backup and Recovery

### Configuration Backup
```bash
# Backup all manifests
kubectl get all -n a1-orchestrator -o yaml > a1-backup-$(date +%Y%m%d).yaml

# Backup secrets (encrypted)
kubectl get secrets -n a1-orchestrator -o yaml > a1-secrets-backup-$(date +%Y%m%d).yaml
```

### Disaster Recovery
```bash
# Reinstall K3s
./infra/01-k3s-install-a1.sh

# Bootstrap platform
./infra/03-terraform-bootstrap.sh

# Restore applications via ArgoCD
kubectl apply -f apps/root-app/app-of-apps.yaml
```

## Monitoring and Alerting

### Dashboard Access
- **Grafana**: http://localhost:3000 (kubectl port-forward)
- **Prometheus**: http://localhost:9090 (kubectl port-forward)
- **ArgoCD**: https://localhost:8080 (kubectl port-forward)

### Key Metrics to Monitor
- **Request Rate**: > 100 req/s normal
- **Error Rate**: < 1% normal
- **P95 Latency**: < 500ms normal
- **Memory Usage**: < 80% normal
- **CPU Usage**: < 70% normal

### Alert Thresholds
- **Critical**: Service down, error rate > 5%, latency > 2s
- **Warning**: CPU > 80%, memory > 85%, error rate > 2%
- **Info**: Deployment events, scaling events

## Troubleshooting Guide

### Common Issues

#### Pod Stuck in Pending
```bash
# Check resource constraints
kubectl describe pod <pod-name> -n a1-orchestrator

# Check node resources
kubectl describe nodes

# Check PVC status
kubectl get pvc -n a1-orchestrator
```

#### Service Unreachable
```bash
# Check service endpoints
kubectl get endpoints -n a1-orchestrator

# Check network policies
kubectl get networkpolicies -n a1-orchestrator

# Test pod-to-pod connectivity
kubectl exec -it <pod> -n a1-orchestrator -- wget -qO- http://<service>:8080/health
```

#### High Error Rate
```bash
# Check application logs
kubectl logs -n a1-orchestrator deployment/<service> --tail=100

# Check for OOM kills
dmesg | grep -i "killed process"

# Check resource limits
kubectl describe pod <pod-name> -n a1-orchestrator
```

### Performance Issues

#### Slow Response Times
```bash
# Check resource utilization
kubectl top pods -n a1-orchestrator

# Check network latency
kubectl exec -it <pod> -n a1-orchestrator -- ping <target-service>

# Check database connections
kubectl exec -it <pod> -n a1-orchestrator -- netstat -an | grep :5432
```

#### Memory Leaks
```bash
# Monitor memory over time
kubectl top pod <pod-name> -n a1-orchestrator

# Check for memory dumps
kubectl exec -it <pod> -n a1-orchestrator -- ls /tmp/

# Restart affected service
kubectl rollout restart deployment/<service> -n a1-orchestrator
```

## Security Incident Response

### Suspected Breach
1. **Isolate**: Scale affected service to 0 replicas
2. **Investigate**: Collect logs and forensics
3. **Remediate**: Update secrets, restart services
4. **Monitor**: Enhanced monitoring for 24 hours

### Policy Violations
```bash
# Check Gatekeeper violations
kubectl get k8srequiredsecuritycontext -n a1-orchestrator

# Review audit logs
journalctl -u k3s | grep audit

# Check admission controller logs
kubectl logs -n gatekeeper-system deployment/gatekeeper-controller-manager
```

## Capacity Planning

### Resource Monitoring
```bash
# Check current resource usage
kubectl top nodes
kubectl top pods -n a1-orchestrator

# Check resource requests vs limits
kubectl describe resourcequota -n a1-orchestrator
```

### Scaling Decisions
- **Scale Up Triggers**: CPU > 70%, Memory > 80%, Queue depth > 100
- **Scale Down Triggers**: CPU < 30%, Memory < 40%, Queue depth < 10
- **Maximum Replicas**: 10 per service (hardware limit)

## Maintenance Windows

### Weekly Maintenance (Sundays 02:00-04:00 UTC)
- Security updates
- Certificate rotation
- Log rotation
- Performance optimization

### Monthly Maintenance (First Sunday 02:00-06:00 UTC)
- K3s version updates
- Platform component updates
- Backup verification
- Disaster recovery testing

## Contact Information

### Escalation Path
1. **L1**: Platform Engineer (15 min response)
2. **L2**: Senior Platform Engineer (30 min response)
3. **L3**: Platform Architect (1 hour response)
4. **L4**: CTO (4 hour response)

### External Dependencies
- **DNS Provider**: Cloudflare
- **Certificate Authority**: Let's Encrypt
- **Container Registry**: GitHub Container Registry
- **Monitoring**: Prometheus Cloud