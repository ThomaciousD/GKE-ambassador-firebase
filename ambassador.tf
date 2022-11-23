# Install Emissary CRDs
resource "null_resource" "aes_crds_yaml" {

  provisioner "local-exec" {
    command = "curl -O https://app.getambassador.io/yaml/edge-stack/${local.ambassador_app_version}/aes-crds.yaml; echo '\n\n Please run: gcloud container clusters get-credentials hellogke --region ${local.region} --project ${local.project_id} && kubectl apply -f aes-crds.yaml'; echo '\n\n Then `touch /tmp/ididit`; I WILL WAIT HERE \n\n'; while ! test -f /tmp/ididit; do sleep 1; done"
  }

  depends_on = [
    google_container_cluster.private
  ]
}

resource "null_resource" "rm_tmp_file" {

  provisioner "local-exec" {
    command = "rm -f /tmp/ididit || true"
  }

  depends_on = [
    null_resource.aes_crds_yaml
  ]
}

data "kubectl_file_documents" "docs" {
    content = file("aes-crds.yaml")
    depends_on = [
      null_resource.aes_crds_yaml
    ]
}

# If download fails to fetch the aes-crds.yaml file
# WARNING: this could lead to a network flooding depending of your proxy because it creates K8S resources in parallel
# Your proxy / provider could ban your requests. 
# resource "kubectl_manifest" "ambassador_crds" {
#     for_each  = data.kubectl_file_documents.docs.manifests
#     yaml_body = each.value
# }

# In case of network issue, please run manually: 
# kubectl apply -f https://app.getambassador.io/yaml/edge-stack/3.3.0/aes-crds.yaml
# See the reason above
# resource "kubectl_manifest" "ambassador_crds" {
#     yaml_body = file("aes-crds.yaml")
# }

# Install Emissary Helm Chart

resource "kubernetes_namespace" "ambassador" {
  metadata {
    name = "ambassador"
  }
}

resource "helm_release" "ambassador" {
  name       = "ambassador"
  repository = "https://app.getambassador.io"
  chart      = "edge-stack"
  version    = local.ambassador_helm_chart_version
  namespace  = kubernetes_namespace.ambassador.metadata[0].name

  depends_on = [
    kubernetes_namespace.ambassador,
    null_resource.aes_crds_yaml
  ]
}

resource "time_sleep" "wait_120_seconds_for_ambassador_deployment" {
  depends_on = [helm_release.ambassador]
  create_duration = "120s"
}

# Firewall

# Allow GKE master to target Ambassador emissary-apiext pod in emissary-system namespace

resource "google_compute_firewall" "ambassador_webhook" {
  name    = "gke-master-to-emissary-ingress-webhook"
  network = data.google_compute_network.net.name

  allow {
    protocol = "tcp"
    ports    = ["8443"]
  }

  source_ranges = [local.gke_master_ipv4_cidr_block]
}

# Ambassador Listeners

resource "kubectl_manifest" "ambassador_listener" {
  yaml_body = <<YAML
  apiVersion: getambassador.io/v3alpha1
  kind: Listener
  metadata:
    name: edge-stack-listener-8080
    namespace: "${kubernetes_namespace.ambassador.metadata[0].name}"
  spec:
    port: 8080
    protocol: HTTP
    securityModel: XFP
    hostBinding:
      namespace:
        from: ALL
  YAML
  depends_on = [
    helm_release.ambassador,
    time_sleep.wait_120_seconds_for_ambassador_deployment
  ]
}

resource "kubectl_manifest" "ambassador_listener_8443" {
  yaml_body=<<YAML
  apiVersion: getambassador.io/v3alpha1
  kind: Listener
  metadata:
    name: edge-stack-listener-8443
    namespace: "${kubernetes_namespace.ambassador.metadata[0].name}"
  spec:
    port: 8443
    protocol: HTTPS
    securityModel: XFP
    hostBinding:
      namespace:
        from: ALL
  YAML
  depends_on = [
    helm_release.ambassador,
    time_sleep.wait_120_seconds_for_ambassador_deployment
  ]
}

# Ambassador external LB IP

data "kubernetes_service" "ambassador" {
  metadata {
    name = "ambassador"
    namespace = "${kubernetes_namespace.ambassador.metadata[0].name}"
  }
  depends_on = [
    helm_release.ambassador
  ]
}

output kubernetes_service_ambassador_lb {
  value = data.kubernetes_service.ambassador.status.0.load_balancer.0.ingress.0.ip
}

locals {
  ambassador_dns = "${data.kubernetes_service.ambassador.status.0.load_balancer.0.ingress.0.ip}.nip.io"
  ambassador_url = "https://${local.ambassador_dns}"
}

output ambassador_dns {
  value = local.ambassador_dns
}

output ambassador_url {
  value = local.ambassador_url
  description = "The URL to target your ambassador API gateway"
}

#### Ambassador Examples with HTTPBIN

# Httpbin namespace
resource "kubernetes_namespace" "httpbin" {
  metadata {
    name = "httpbin"
  }
}

# Httpbin mapping
resource "kubectl_manifest" "httpbin_mapping" {
  yaml_body = <<YAML
        apiVersion: getambassador.io/v3alpha1
        kind:  Mapping
        metadata:
          name:  httpbin
          namespace: "${kubernetes_namespace.httpbin.metadata[0].name}"
        spec:
          hostname: "*"
          prefix: /httpbin/
          service: httpbin.org:80
          host_rewrite: httpbin.org
YAML
  depends_on = [
    helm_release.ambassador, kubernetes_namespace.httpbin,
    time_sleep.wait_120_seconds_for_ambassador_deployment
  ]
}

# Httpbin mapping output
output httpbin_url {
  value = "${local.ambassador_url}/httpbin/"
  description="Test your ambassador mapping, open this url: "
}

# Ambassador SSL

### Lets encrypt for Ambassador
# Cluster Issuer
resource "kubectl_manifest" "ambassador_cluster_issuer" {
  yaml_body = <<YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
      namespace: ambassador
    spec:
      acme:
        email: ${local.cert_issuer_email}
        server: https://acme-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: letsencrypt-prod
        solvers:
        - http01:
            ingress:
              class: nginx
          selector: {}
YAML
  depends_on = [
    helm_release.cert_manager, helm_release.ambassador,
    time_sleep.wait_120_seconds_for_certmanager_deployment
  ]
}

# Certificate
resource "kubectl_manifest" "ambassador_certificate" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ambassador-certs
  namespace: ambassador
spec:
  secretName: ambassador-certs
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - ${data.kubernetes_service.ambassador.status.0.load_balancer.0.ingress.0.ip}.nip.io
YAML
  depends_on = [
    helm_release.cert_manager, helm_release.ambassador,
    time_sleep.wait_120_seconds_for_certmanager_deployment
  ]
}

# ACME kubernetes service
resource "kubectl_manifest" "acme_challenge_service" {
  yaml_body = <<YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: acme-challenge-service
      namespace: ambassador
    spec:
      ports:
      - port: 80
        targetPort: 8089
      selector:
        acme.cert-manager.io/http01-solver: "true"
  YAML
  depends_on = [
    helm_release.ambassador
  ]
}

## ACME mapper for Let's Encrypt 
# https://www.getambassador.io/docs/edge-stack/latest/howtos/cert-manager/
resource "kubectl_manifest" "acme_challenge_mapping" {
  yaml_body = <<YAML
    apiVersion: getambassador.io/v3alpha1
    kind: Mapping
    metadata:
      name: acme-challenge-mapping
      namespace: ambassador
    spec:
      hostname: "*"
      prefix: /.well-known/acme-challenge/
      rewrite: ""
      service: acme-challenge-service
    docs:
      ignored: true
  YAML
  depends_on = [
    helm_release.ambassador,
    time_sleep.wait_120_seconds_for_ambassador_deployment
  ]
}

# Configure Host and TLS for the ingress of Ambassador
# https://www.getambassador.io/docs/edge-stack/latest/topics/running/host-crd/ 
resource "kubectl_manifest" "ambassador_host" {
  yaml_body=<<YAML
  apiVersion: getambassador.io/v3alpha1
  kind: Host
  metadata:
    name: ambassador-host
    namespace: ambassador
  spec:
    hostname: ${local.ambassador_dns}
    acmeProvider:
      email: ${local.cert_issuer_email}
    tlsSecret:
      name: ambassador-certs
  YAML
  depends_on = [
    helm_release.ambassador,
    time_sleep.wait_120_seconds_for_ambassador_deployment
  ]
}