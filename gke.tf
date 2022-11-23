resource "google_container_cluster" "private" {
  provider                 = google-beta

  name                     = "hellogke"
  location                 = local.region

  network                  = local.network
  subnetwork               = local.subnet

  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes    = true
    master_ipv4_cidr_block  = local.gke_master_ipv4_cidr_block
  }

  ip_allocation_policy {
  }

  # Enable Autopilot for this cluster
  enable_autopilot = true

  # Configuration options for the Release channel feature, which provide more control over automatic upgrades of your GKE clusters.
  release_channel {
    channel = "REGULAR"
  }
}
