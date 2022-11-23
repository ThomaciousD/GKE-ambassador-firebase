terraform {
  required_version = ">= 0.13"

  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 3.63.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 3.63.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

provider "google" {
  project = local.project_id
  region  = local.region
}

provider "google-beta" {
  project = local.project_id
  region  = local.region
}

data "google_client_config" "provider" {}

provider kubernetes {
  host                   = "https://${google_container_cluster.private.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.private.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.provider.access_token
}

provider "kubectl" {
  host                   = google_container_cluster.private.endpoint
  cluster_ca_certificate = base64decode(google_container_cluster.private.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.provider.access_token
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = google_container_cluster.private.endpoint
    cluster_ca_certificate = base64decode(google_container_cluster.private.master_auth.0.cluster_ca_certificate)
    token                  = data.google_client_config.provider.access_token
  }
}