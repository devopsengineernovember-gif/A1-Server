# Create required namespaces
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/component" = "argocd"
      "app.kubernetes.io/part-of"   = "platform"
    }
  }
}

resource "kubernetes_namespace" "gatekeeper_system" {
  metadata {
    name = "gatekeeper-system"
    labels = {
      "admission.gatekeeper.sh/ignore" = "no-self-managing"
      "app.kubernetes.io/component"    = "gatekeeper"
      "app.kubernetes.io/part-of"      = "platform"
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
    labels = {
      "app.kubernetes.io/component" = "external-secrets"
      "app.kubernetes.io/part-of"   = "platform"
    }
  }
}

resource "kubernetes_namespace" "keda" {
  metadata {
    name = "keda"
    labels = {
      "app.kubernetes.io/component" = "keda"
      "app.kubernetes.io/part-of"   = "platform"
    }
  }
}

resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
    labels = {
      "app.kubernetes.io/component" = "monitoring"
      "app.kubernetes.io/part-of"   = "platform"
    }
  }
}

resource "kubernetes_namespace" "orchestrator" {
  metadata {
    name = "orchestrator"
    labels = {
      "app.kubernetes.io/component" = "orchestrator"
      "app.kubernetes.io/part-of"   = "applications"
      "plane"                       = "control"
      "host"                        = "A1"
      "team"                        = "orchestrator"
      "pod-security.kubernetes.io/enforce" = "baseline"
      "pod-security.kubernetes.io/audit"   = "baseline"
      "pod-security.kubernetes.io/warn"    = "baseline"
    }
  }
}

# ArgoCD installation
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [file("${path.module}/values/argocd-values.yaml")]

  depends_on = [kubernetes_namespace.argocd]
}

# OPA Gatekeeper installation
resource "helm_release" "gatekeeper" {
  name       = "gatekeeper"
  repository = "https://open-policy-agent.github.io/gatekeeper/charts"
  chart      = "gatekeeper"
  version    = "3.14.0"
  namespace  = kubernetes_namespace.gatekeeper_system.metadata[0].name

  values = [file("${path.module}/values/gatekeeper-values.yaml")]

  depends_on = [kubernetes_namespace.gatekeeper_system]
}

# External Secrets Operator installation
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.9.11"
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name

  values = [file("${path.module}/values/external-secrets-values.yaml")]

  depends_on = [kubernetes_namespace.external_secrets]
}

# KEDA installation
resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = "2.12.1"
  namespace  = kubernetes_namespace.keda.metadata[0].name

  values = [file("${path.module}/values/keda-values.yaml")]

  depends_on = [kubernetes_namespace.keda]
}

# Prometheus stack installation
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.5.0"
  namespace  = kubernetes_namespace.observability.metadata[0].name

  values = [file("${path.module}/values/prometheus-values.yaml")]

  depends_on = [kubernetes_namespace.observability]
}