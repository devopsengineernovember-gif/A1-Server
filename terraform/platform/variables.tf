variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "a1-cluster"
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"
}

variable "gatekeeper_version" {
  description = "Gatekeeper Helm chart version"
  type        = string
  default     = "3.14.0"
}

variable "external_secrets_version" {
  description = "External Secrets Helm chart version"
  type        = string
  default     = "0.9.11"
}

variable "keda_version" {
  description = "KEDA Helm chart version"
  type        = string
  default     = "2.12.1"
}

variable "prometheus_version" {
  description = "Prometheus stack Helm chart version"
  type        = string
  default     = "55.5.0"
}

variable "node_selector" {
  description = "Node selector for platform components"
  type        = map(string)
  default = {
    "node-role" = "control"
    "host"      = "A1"
  }
}

variable "tolerations" {
  description = "Tolerations for platform components"
  type = list(object({
    key      = string
    operator = string
    value    = string
    effect   = string
  }))
  default = [{
    key      = "dedicated"
    operator = "Equal"
    value    = "control"
    effect   = "NoSchedule"
  }]
}

variable "enable_argocd_notifications" {
  description = "Enable ArgoCD notifications"
  type        = bool
  default     = false
}

variable "enable_prometheus_alertmanager" {
  description = "Enable Prometheus AlertManager"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "prom-operator"
  sensitive   = true
}