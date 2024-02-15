resource "google_compute_network" "vpc" {
  name                    = "${var.vpc_name}"
  auto_create_subnetworks = false
  routing_mode            = "${var.routing_mode}"
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "webapp_subnet" {
  name          = "${var.webapp_subnet_name}"
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = "${var.webapp_subnet_cidr}"
}

resource "google_compute_subnetwork" "db_subnet" {
  name          = "${var.db_subnet_name}"
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = "${var.db_subnet_cidr}"
}

resource "google_compute_route" "webapp_route" {
  name                 = "${var.webapp_route_name}"
  network              = google_compute_network.vpc.self_link
  dest_range           = "${var.webapp_subnet_dest_range}"
  next_hop_gateway     = "default-internet-gateway"
}
