data "google_compute_network" "net" {
  name = local.network
}

data "google_compute_subnetwork" "subnet" {
  name   = local.subnet
  region = local.region
}