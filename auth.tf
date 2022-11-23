# These are the resources to protect an API with Firebase authentication
# We will deploy an hello world app protected with Firebase authentication

# Create a namespace for the Hello World deployment
resource "kubernetes_namespace" "hello_world" {
  metadata {
    name = "hello-world"
  }
}

# Create the Hello world deployment
resource "kubectl_manifest" "hello_world_deployment" {
    yaml_body=<<YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: hello-world
      namespace: ${kubernetes_namespace.hello_world.metadata[0].name}
    labels:
        app: hello-world
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: hello-world
      template:
        metadata:
          labels:
            app: hello-world
        spec:
          containers:
          - name: hello-world
            image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
            ports:
            - containerPort: 80
    YAML
}

# Create the Hello world service
resource "kubectl_manifest" "hello_world_service" {
    yaml_body=<<YAML
    apiVersion: v1
    kind: Service
    metadata:
      name: hello-world
      namespace: ${kubernetes_namespace.hello_world.metadata[0].name}
    spec:
      type: NodePort
      ports:
      - port: 80
        protocol: TCP
        targetPort: 8080
      selector:
        app: hello-world
    YAML
}

# Create ambassador mapping
resource "kubectl_manifest" "hello_world_mapping" {
    yaml_body=<<YAML
    apiVersion: getambassador.io/v3alpha1
    kind:  Mapping
    metadata:
      name: hello-world
      namespace: ${kubernetes_namespace.hello_world.metadata[0].name}
    spec:
      hostname: "*"
      prefix: /hello-world/
      service: http://hello-world.hello-world.svc.cluster.local:80
    YAML
    depends_on = [
      helm_release.ambassador,
      time_sleep.wait_120_seconds_for_ambassador_deployment
    ]
}

resource "kubectl_manifest" "hello_world_mapping_custom" {
    yaml_body=<<YAML
    apiVersion: getambassador.io/v3alpha1
    kind:  Mapping
    metadata:
      name: hello-world-custom
      namespace: ${kubernetes_namespace.hello_world.metadata[0].name}
    spec:
      hostname: "*"
      prefix: /hello-world-custom/
      service: http://hello-world.hello-world.svc.cluster.local:80
    YAML
    depends_on = [
      helm_release.ambassador,
      time_sleep.wait_120_seconds_for_ambassador_deployment
    ]
}

# Create Ambassador filter for JWT on Firebase
# Create ambassador mapping
# The user token is signed with generic securetoken firebase service account
# jwksURI:            "https://www.googleapis.com/service_accounts/v1/metadata/x509/securetoken@system.gserviceaccount.com"
resource "kubectl_manifest" "firebase_jwt_filter" {
    yaml_body=<<YAML
apiVersion: getambassador.io/v2
kind: Filter
metadata:
  name: "firebase-filter"
  namespace: ${kubernetes_namespace.hello_world.metadata[0].name}
spec:
  JWT:
    jwksURI:  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"
    audience: "${local.project_id}"
    issuer:   "https://securetoken.google.com/${local.project_id}"
YAML
  depends_on = [
      helm_release.ambassador,
      time_sleep.wait_120_seconds_for_ambassador_deployment
  ]
}

# Create Ambassador filter for Custom JWT on Firebase
data "google_service_account" "jwt_issuer_sa" {
  account_id = local.jwt_service_account_issuer
}

resource "kubectl_manifest" "firebase_custom_jwt_filter" {
    yaml_body=<<YAML
apiVersion: getambassador.io/v2
kind: Filter
metadata:
  name: "firebase-custom-filter"
  namespace: ${kubernetes_namespace.hello_world.metadata[0].name}
spec:
  JWT:
    audience: "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit"
    jwksURI:  "https://www.googleapis.com/service_accounts/v1/jwk/${data.google_service_account.jwt_issuer_sa.email}"
    issuer:   "${data.google_service_account.jwt_issuer_sa.email}"
YAML
  depends_on = [
      helm_release.ambassador,
      time_sleep.wait_120_seconds_for_ambassador_deployment
  ]
}

# Now protect the Hello World mapping with the Firebase auth filter
resource "kubectl_manifest" "firebase_jwt_filter_policy" {
    yaml_body=<<YAML
apiVersion: getambassador.io/v3alpha1
kind: FilterPolicy
metadata:
  name: "firebase-filter-policy"
  namespace: ${kubernetes_namespace.hello_world.metadata[0].name}
spec:
  rules:
  - path: "/hello-world/"
    host: "*"
    filters:                    
    - name: "firebase-filter"
      namespace: "${kubernetes_namespace.hello_world.metadata[0].name}"
  - path: "/hello-world-custom/"
    host: "*"
    filters:                    
    - name: "firebase-custom-filter"
      namespace: "${kubernetes_namespace.hello_world.metadata[0].name}"

    YAML
  depends_on = [
      helm_release.ambassador,
      time_sleep.wait_120_seconds_for_ambassador_deployment
  ]
}

# Outputs

output hello_world_jwt_backend {
  value="curl -H \"Authorization: Bearer $JWT_TOKEN\" ${local.ambassador_url}/hello-world/"
}

output hello_world_jwt_custom_backend {
  value="curl -H \"Authorization: Bearer $JWT_CUSTOM_TOKEN\" ${local.ambassador_url}/hello-world-custom/"
}