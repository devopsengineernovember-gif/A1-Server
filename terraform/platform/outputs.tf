output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = var.cluster_name
}

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_server_service" {
  description = "ArgoCD server service name"
  value       = "argocd-server"
}

output "gatekeeper_namespace" {
  description = "Gatekeeper namespace"
  value       = kubernetes_namespace.gatekeeper_system.metadata[0].name
}

output "external_secrets_namespace" {
  description = "External Secrets namespace"
  value       = kubernetes_namespace.external_secrets.metadata[0].name
}

output "keda_namespace" {
  description = "KEDA namespace"
  value       = kubernetes_namespace.keda.metadata[0].name
}

output "observability_namespace" {
  description = "Observability namespace"
  value       = kubernetes_namespace.observability.metadata[0].name
}

output "orchestrator_namespace" {
  description = "Orchestrator namespace"
  value       = kubernetes_namespace.orchestrator.metadata[0].name
}

output "grafana_service" {
  description = "Grafana service name"
  value       = "prometheus-grafana"
}

output "prometheus_service" {
  description = "Prometheus service name"
  value       = "prometheus-kube-prometheus-prometheus"
}

output "platform_ready" {
  description = "Indicates if platform components are deployed"
  value       = "Platform components deployed successfully"
  depends_on = [
    helm_release.argocd,
    helm_release.gatekeeper,
    helm_release.external_secrets,
    helm_release.keda,
    helm_release.prometheus
  ]
}