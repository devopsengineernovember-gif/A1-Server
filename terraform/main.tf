# Platform Bootstrap Configuration
# Installs core platform components on K3s cluster

# =================================================================
# Local Variables
# =================================================================
locals {
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "platform" = "ai-agents"
    "cluster" = "a1"
  }
  
  # Node selector for control plane
  control_plane_selector = {
    "kubernetes.io/role" = "control-plane"
  }
  
  # Monitoring namespace
  monitoring_namespace = "monitoring"
  argocd_namespace = "argocd"
  security_namespace = "gatekeeper-system"
  secrets_namespace = "external-secrets-system"
  autoscaling_namespace = "keda"
}

# =================================================================
# Namespaces
# =================================================================
resource "kubernetes_namespace" "platform_namespaces" {
  for_each = toset([
    local.argocd_namespace,
    local.monitoring_namespace,
    local.security_namespace,
    local.secrets_namespace,
    local.autoscaling_namespace
  ])
  
  metadata {
    name = each.value
    labels = merge(local.common_labels, {
      "name" = each.value
      "app.kubernetes.io/component" = "platform"
    })
  }
}

# =================================================================
# ArgoCD Installation
# =================================================================
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = local.argocd_namespace
  
  values = [
    yamlencode({
      global = {
        domain = var.cluster_domain
      }
      
      configs = {
        params = {
          "server.insecure" = var.argocd_insecure
          "server.grpc.web" = true
          "server.disable.auth" = false
          "reposerver.parallelism.limit" = 10
        }
        
        cm = {
          "exec.enabled" = "false"
          "admin.enabled" = "true"
          "timeout.reconciliation" = "180s"
          "timeout.hard.reconciliation" = "0s"
          "application.instanceLabelKey" = "argocd.argoproj.io/instance"
          "server.rbac.log.enforce.enable" = "true"
          
          # OIDC configuration placeholder
          "url" = "https://argocd.${var.cluster_domain}"
          "oidc.config" = var.oidc_enabled ? yamlencode({
            name = "OIDC"
            issuer = var.oidc_issuer_url
            clientId = var.oidc_client_id
            clientSecret = "$oidc.clientSecret"
            requestedScopes = ["openid", "profile", "email"]
            requestedIDTokenClaims = {
              groups = {
                essential = true
              }
            }
          }) : ""
        }
        
        rbac = {
          "policy.default" = "role:readonly"
          "policy.csv" = <<-EOT
            p, role:admin, applications, *, */*, allow
            p, role:admin, clusters, *, *, allow
            p, role:admin, repositories, *, *, allow
            g, argocd-admins, role:admin
          EOT
        }
        
        secret = var.oidc_enabled ? {
          "oidc.clientSecret" = var.oidc_client_secret
        } : {}
      }
      
      controller = {
        replicas = 1
        nodeSelector = local.control_plane_selector
        resources = {
          requests = {
            cpu = "500m"
            memory = "1Gi"
          }
          limits = {
            cpu = "2000m"
            memory = "4Gi"
          }
        }
        
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }
      
      server = {
        replicas = 1
        nodeSelector = local.control_plane_selector
        resources = {
          requests = {
            cpu = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu = "1000m"
            memory = "2Gi"
          }
        }
        
        service = {
          type = "ClusterIP"
        }
        
        ingress = {
          enabled = true
          ingressClassName = "traefik"
          hosts = ["argocd.${var.cluster_domain}"]
          tls = [{
            secretName = "argocd-tls"
            hosts = ["argocd.${var.cluster_domain}"]
          }]
        }
        
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }
      
      repoServer = {
        replicas = 1
        nodeSelector = local.control_plane_selector
        resources = {
          requests = {
            cpu = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu = "1000m"
            memory = "2Gi"
          }
        }
        
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }
      
      applicationSet = {
        enabled = true
        replicas = 1
        nodeSelector = local.control_plane_selector
        resources = {
          requests = {
            cpu = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu = "500m"
            memory = "1Gi"
          }
        }
      }
      
      notifications = {
        enabled = true
        nodeSelector = local.control_plane_selector
        resources = {
          requests = {
            cpu = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu = "500m"
            memory = "512Mi"
          }
        }
      }
    })
  ]
  
  depends_on = [kubernetes_namespace.platform_namespaces]
}

# =================================================================
# OPA Gatekeeper Installation
# =================================================================
resource "helm_release" "gatekeeper" {
  name       = "gatekeeper"
  repository = "https://open-policy-agent.github.io/gatekeeper/charts"
  chart      = "gatekeeper"
  version    = var.gatekeeper_version
  namespace  = local.security_namespace
  
  values = [
    yamlencode({
      replicas = 1
      nodeSelector = local.control_plane_selector
      
      controllerManager = {
        nodeSelector = local.control_plane_selector
        resources = {
          requests = {
            cpu = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu = "1000m"
            memory = "2Gi"
          }
        }
        
        securityContext = {
          runAsUser = 65532
          runAsGroup = 65532
          runAsNonRoot = true
          readOnlyRootFilesystem = true
          allowPrivilegeEscalation = false
          capabilities = {
            drop = ["ALL"]
          }
          seccompProfile = {
            type = "RuntimeDefault"
          }
        }
      }
      
      audit = {
        nodeSelector = local.control_plane_selector
        resources = {
          requests = {
            cpu = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu = "500m"
            memory = "1Gi"
          }
        }
      }
      
      postInstall = {
        labelNamespace = {
          enabled = true
          image = {
            repository = "openpolicyagent/gatekeeper-crds"
            tag = "v3.14.0"
          }
        }
      }
      
      violations = {
        allowedUsers = ["admin", "system:admin"]
      }
      
      enableRuntimeDefaultSeccompProfile = true
      mutatingWebhookFailurePolicy = "Fail"
      validatingWebhookFailurePolicy = "Fail"
      
      # Image security
      image = {
        repository = "openpolicyagent/gatekeeper"
        tag = "v3.14.0"
        pullPolicy = "IfNotPresent"
      }
    })
  ]
  
  depends_on = [kubernetes_namespace.platform_namespaces]
}

# =================================================================
# External Secrets Operator Installation
# =================================================================
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.external_secrets_version
  namespace  = local.secrets_namespace
  
  values = [
    yamlencode({
      installCRDs = true
      nodeSelector = local.control_plane_selector
      
      resources = {
        requests = {
          cpu = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu = "500m"
          memory = "1Gi"
        }
      }
      
      webhook = {
        nodeSelector = local.control_plane_selector
        resources = {
          requests = {
            cpu = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu = "200m"
            memory = "512Mi"
          }
        }
      }
      
      certController = {
        nodeSelector = local.control_plane_selector
        resources = {
          requests = {
            cpu = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu = "200m"
            memory = "512Mi"
          }
        }
      }
      
      serviceMonitor = {
        enabled = true
      }
      
      securityContext = {
        runAsNonRoot = true
        runAsUser = 65534
        readOnlyRootFilesystem = true
        allowPrivilegeEscalation = false
        capabilities = {
          drop = ["ALL"]
        }
        seccompProfile = {
          type = "RuntimeDefault"
        }
      }
    })
  ]
  
  depends_on = [kubernetes_namespace.platform_namespaces]
}

# =================================================================
# KEDA Installation
# =================================================================
resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.keda_version
  namespace  = local.autoscaling_namespace
  
  values = [
    yamlencode({
      operator = {
        nodeSelector = local.control_plane_selector
        resources = {
          requests = {
            cpu = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu = "1000m"
            memory = "2Gi"
          }
        }
      }
      
      metricsServer = {
        nodeSelector = local.control_plane_selector
        resources = {
          requests = {
            cpu = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu = "1000m"
            memory = "2Gi"
          }
        }
      }
      
      webhooks = {
        nodeSelector = local.control_plane_selector
        resources = {
          requests = {
            cpu = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu = "500m"
            memory = "1Gi"
          }
        }
      }
      
      serviceMonitor = {
        enabled = true
      }
      
      podSecurityContext = {
        runAsNonRoot = true
        runAsUser = 1001
        fsGroup = 1001
        seccompProfile = {
          type = "RuntimeDefault"
        }
      }
      
      securityContext = {
        readOnlyRootFilesystem = true
        allowPrivilegeEscalation = false
        capabilities = {
          drop = ["ALL"]
        }
      }
    })
  ]
  
  depends_on = [kubernetes_namespace.platform_namespaces]
}

# =================================================================
# Prometheus Stack Installation
# =================================================================
resource "helm_release" "prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_stack_version
  namespace  = local.monitoring_namespace
  
  values = [
    yamlencode({
      nameOverride = "prometheus"
      fullnameOverride = "prometheus"
      
      prometheus = {
        prometheusSpec = {
          nodeSelector = local.control_plane_selector
          retention = var.prometheus_retention
          retentionSize = var.prometheus_storage_size
          
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          }
          
          resources = {
            requests = {
              cpu = "500m"
              memory = "2Gi"
            }
            limits = {
              cpu = "4000m"
              memory = "8Gi"
            }
          }
          
          securityContext = {
            runAsUser = 65534
            runAsGroup = 65534
            runAsNonRoot = true
            fsGroup = 65534
            seccompProfile = {
              type = "RuntimeDefault"
            }
          }
          
          # Enable ServiceMonitor discovery across all namespaces
          serviceMonitorSelectorNilUsesHelmValues = false
          ruleSelectorNilUsesHelmValues = false
          
          additionalScrapeConfigs = [
            {
              job_name = "kubernetes-pods"
              kubernetes_sd_configs = [
                {
                  role = "pod"
                }
              ]
              relabel_configs = [
                {
                  source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                  action = "keep"
                  regex = "true"
                },
                {
                  source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
                  action = "replace"
                  target_label = "__metrics_path__"
                  regex = "(.+)"
                }
              ]
            }
          ]
        }
      }
      
      alertmanager = {
        alertmanagerSpec = {
          nodeSelector = local.control_plane_selector
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
          resources = {
            requests = {
              cpu = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu = "500m"
              memory = "1Gi"
            }
          }
        }
      }
      
      grafana = {
        nodeSelector = local.control_plane_selector
        adminPassword = var.grafana_admin_password
        
        persistence = {
          enabled = true
          storageClassName = var.storage_class
          size = "10Gi"
        }
        
        resources = {
          requests = {
            cpu = "200m"
            memory = "512Mi"
          }
          limits = {
            cpu = "1000m"
            memory = "2Gi"
          }
        }
        
        ingress = {
          enabled = true
          ingressClassName = "traefik"
          hosts = ["grafana.${var.cluster_domain}"]
          tls = [{
            secretName = "grafana-tls"
            hosts = ["grafana.${var.cluster_domain}"]
          }]
        }
        
        sidecar = {
          dashboards = {
            enabled = true
            searchNamespace = "ALL"
            folderAnnotation = "grafana_folder"
            provider = {
              foldersFromFilesStructure = true
            }
          }
          datasources = {
            enabled = true
            defaultDatasourceEnabled = true
          }
        }
        
        # Security context
        securityContext = {
          runAsUser = 472
          runAsGroup = 472
          runAsNonRoot = true
          allowPrivilegeEscalation = false
          capabilities = {
            drop = ["ALL"]
          }
          seccompProfile = {
            type = "RuntimeDefault"
          }
        }
        
        # Additional data sources
        additionalDataSources = [
          {
            name = "Loki"
            type = "loki"
            url = "http://loki.monitoring.svc.cluster.local:3100"
            access = "proxy"
            isDefault = false
          }
        ]
      }
      
      kubeStateMetrics = {
        nodeSelector = local.control_plane_selector
      }
      
      nodeExporter = {
        enabled = true
      }
      
      prometheusOperator = {
        nodeSelector = local.control_plane_selector
        resources = {
          requests = {
            cpu = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu = "500m"
            memory = "1Gi"
          }
        }
        
        securityContext = {
          runAsUser = 65534
          runAsGroup = 65534
          runAsNonRoot = true
          allowPrivilegeEscalation = false
          capabilities = {
            drop = ["ALL"]
          }
          seccompProfile = {
            type = "RuntimeDefault"
          }
        }
      }
    })
  ]
  
  depends_on = [kubernetes_namespace.platform_namespaces]
}

# =================================================================
# ArgoCD Root Application
# =================================================================
resource "kubectl_manifest" "argocd_root_app" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind = "Application"
    metadata = {
      name = "root-app"
      namespace = local.argocd_namespace
      labels = merge(local.common_labels, {
        "app.kubernetes.io/name" = "root-app"
        "app.kubernetes.io/component" = "application"
      })
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL = var.git_repository_url
        targetRevision = var.git_target_revision
        path = "k8s-manifests/root-app"
      }
      destination = {
        server = "https://kubernetes.default.svc"
        namespace = local.argocd_namespace
      }
      syncPolicy = {
        automated = {
          prune = true
          selfHeal = true
          allowEmpty = false
        }
        syncOptions = [
          "CreateNamespace=true",
          "PrunePropagationPolicy=foreground",
          "PruneLast=true"
        ]
        retry = {
          limit = 5
          backoff = {
            duration = "5s"
            factor = 2
            maxDuration = "3m"
          }
        }
      }
      revisionHistoryLimit = 10
    }
  })
  
  depends_on = [helm_release.argocd]
}

# =================================================================
# Outputs
# =================================================================
output "cluster_info" {
  description = "Cluster connection information"
  value = {
    endpoint = "https://localhost:6443"
    domain = var.cluster_domain
    kubeconfig_path = "~/.kube/config"
  }
}

output "service_urls" {
  description = "Service access URLs"
  value = {
    argocd = "https://argocd.${var.cluster_domain}"
    grafana = "https://grafana.${var.cluster_domain}"
    prometheus = "http://localhost:9090"  # Port-forward required
    alertmanager = "http://localhost:9093"  # Port-forward required
  }
}

output "argocd_admin_password" {
  description = "ArgoCD admin password retrieval command"
  value = "kubectl -n ${local.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
  sensitive = false
}