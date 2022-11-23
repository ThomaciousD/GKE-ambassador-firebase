variable GCP_PROJECT {
    type = string
}

variable CERT_EMAIL {
    type = string
}

variable GCP_REGION {
    type = string
    default = "europe-west1"
}

variable GKE_MASTER_CIDR {
    type = string
    default = "172.23.0.0/28"
}

variable GCP_NETWORK_NAME {
    type = string
    default = "default"
}

variable GCP_SUBNET_NAME {
    type = string
    default = "default"
}

variable CERT_MANAGER_HELM_CHART_VERSION {
    type = string
    default = "v1.10.0"
}

variable AMBASSADOR_HELM_CHART_VERSION {
    type = string
    default = "8.3.0"
} 

variable AMBASSADOR_APP_VERSION {
    type = string
    default = "3.3.0"
}
variable JWT_SERVICE_ACCOUND_ISSUER_ID {
    type = string
    default = "terraform"
}