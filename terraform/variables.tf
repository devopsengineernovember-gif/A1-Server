# =================================================================
# Variables for K3s AI Platform
# =================================================================

variable "cluster_domain" {
  description = "Base domain for cluster services"
  type        = string
  default     = "a1.local"
}

variable "git_repository_url" {
  description = "Git repository URL for Kubernetes manifests"
  type        = string
  default     = "https://github.com/devopsengineernovember-gif/k3s-ai-platform"
}

variable "git_target_revision" {
  description = "Git branch or tag to sync from"
  type        = string
  default     = "HEAD"
}

# =================================================================
# Platform Component Versions
# =================================================================

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"
}

variable "gatekeeper_version" {
  description = "OPA Gatekeeper Helm chart version"
  type        = string
  default     = "3.14.0"
}

variable "external_secrets_version" {
  description = "External Secrets Operator Helm chart version"
  type        = string
  default     = "0.9.11"
}

variable "keda_version" {
  description = "KEDA Helm chart version"
  type        = string
  default     = "2.12.1"
}

variable "prometheus_stack_version" {
  description = "Prometheus Stack Helm chart version"
  type        = string
  default     = "55.5.0"
}

# =================================================================
# ArgoCD Configuration
# =================================================================

variable "argocd_insecure" {
  description = "Run ArgoCD server in insecure mode (disable TLS)"
  type        = bool
  default     = true
}

variable "oidc_enabled" {
  description = "Enable OIDC authentication for ArgoCD"
  type        = bool
  default     = false
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL"
  type        = string
  default     = ""
  sensitive   = true
}

variable "oidc_client_id" {
  description = "OIDC client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "oidc_client_secret" {
  description = "OIDC client secret"
  type        = string
  default     = ""
  sensitive   = true
}

# =================================================================
# Monitoring Configuration
# =================================================================

variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "15d"
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "50Gi"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin123"
  sensitive   = true
}

# =================================================================
# Storage Configuration
# =================================================================

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "local-path"
}

# =================================================================
# Security Configuration
# =================================================================

variable "pod_security_standards" {
  description = "Pod Security Standards level (privileged, baseline, restricted)"
  type        = string
  default     = "baseline"
  
  validation {
    condition = contains(["privileged", "baseline", "restricted"], var.pod_security_standards)
    error_message = "Pod security standard must be one of: privileged, baseline, restricted."
  }
}

variable "network_policies_enabled" {
  description = "Enable network policies for namespace isolation"
  type        = bool
  default     = true
}

variable "enable_admission_controllers" {
  description = "Enable additional admission controllers"
  type        = bool
  default     = true
}

# =================================================================
# Resource Configuration
# =================================================================

variable "resource_quotas_enabled" {
  description = "Enable resource quotas for namespaces"
  type        = bool
  default     = true
}

variable "enable_monitoring_persistence" {
  description = "Enable persistent storage for monitoring components"
  type        = bool
  default     = true
}

# =================================================================
# Local Values
# =================================================================
locals {
  # Common labels for all resources
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "platform" = "ai-agents"
    "cluster" = "a1"
    "version" = "1.0.0"
  }
  
  # Resource sizing templates
  resource_profiles = {
    nano = {
      requests = { cpu = "50m", memory = "64Mi" }
      limits = { cpu = "200m", memory = "256Mi" }
    }
    micro = {
      requests = { cpu = "100m", memory = "128Mi" }
      limits = { cpu = "500m", memory = "512Mi" }
    }
    small = {
      requests = { cpu = "250m", memory = "512Mi" }
      limits = { cpu = "1000m", memory = "2Gi" }
    }
    medium = {
      requests = { cpu = "500m", memory = "1Gi" }
      limits = { cpu = "2000m", memory = "4Gi" }
    }
    large = {
      requests = { cpu = "1000m", memory = "2Gi" }
      limits = { cpu = "4000m", memory = "8Gi" }
    }
  }
  
  # Security contexts
  security_contexts = {
    non_root = {
      runAsNonRoot = true
      runAsUser = 65534
      runAsGroup = 65534
      allowPrivilegeEscalation = false
      readOnlyRootFilesystem = true
      capabilities = {
        drop = ["ALL"]
      }
      seccompProfile = {
        type = "RuntimeDefault"
      }
    }
    
    restricted = {
      runAsNonRoot = true
      runAsUser = 1000
      runAsGroup = 1000
      allowPrivilegeEscalation = false
      readOnlyRootFilesystem = true
      capabilities = {
        drop = ["ALL"]
      }
      seccompProfile = {
        type = "RuntimeDefault"
      }
    }
  }
}