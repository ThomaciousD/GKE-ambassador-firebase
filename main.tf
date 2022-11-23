locals {
    project_id = var.GCP_PROJECT
    region = var.GCP_REGION
    gke_master_ipv4_cidr_block = var.GKE_MASTER_CIDR
    network = var.GCP_NETWORK_NAME
    subnet = var.GCP_SUBNET_NAME
    cert_manager_helm_chart_version = var.CERT_MANAGER_HELM_CHART_VERSION
    cert_issuer_email = var.CERT_EMAIL
    ambassador_app_version=var.AMBASSADOR_APP_VERSION
    ambassador_helm_chart_version=var.AMBASSADOR_HELM_CHART_VERSION
    jwt_service_account_issuer = var.JWT_SERVICE_ACCOUND_ISSUER_ID
}