## Cert manager
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

# Install the Helm chart
resource helm_release cert_manager {
    
    name       = "cert-manager"
    chart      = "cert-manager"
    repository = "https://charts.jetstack.io"
    version    = local.cert_manager_helm_chart_version
    namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  set {
    name = "prometheus.enabled"
    value = false
  }

  set {
    name = "global.leaderElection.namespace"
    value = "cert-manager"
  }

  set {
    name = "installCRDs"
    value = true
  }

  depends_on = [
    kubernetes_namespace.cert_manager
  ]
}

## Wait for 2 minutes for Helm release deployment
resource "time_sleep" "wait_120_seconds_for_certmanager_deployment" {
  depends_on = [helm_release.cert_manager]

  create_duration = "120s"
}