resource "google_compute_network" "vpc" {
  name                            = var.vpc_name
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "webapp_subnet" {
  name          = var.webapp_subnet_name
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = var.webapp_subnet_cidr
}

resource "google_compute_subnetwork" "db_subnet" {
  name          = var.db_subnet_name
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = var.db_subnet_cidr
}

resource "google_compute_route" "webapp_route" {
  name             = var.webapp_route_name
  network          = google_compute_network.vpc.self_link
  dest_range       = var.webapp_subnet_dest_range
  next_hop_gateway = "default-internet-gateway"
}

# Define a firewall rule to block SSH traffic from the internet
resource "google_compute_firewall" "block_ssh" {
  name    = "block-ssh-from-internet"
  network = google_compute_network.vpc.self_link

  deny {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["${var.webapp_subnet_dest_range}"]
  target_tags   = ["webapp", "db"]
}

# Define a firewall rule for webapp subnet to allow traffic on a specific port
resource "google_compute_firewall" "webapp_firewall" {
  name    = "allow-webapp-traffic"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  source_ranges = ["${var.webapp_subnet_dest_range}"]
  target_tags   = ["webapp"]
}

# Define a Compute Engine instance (VM)
resource "google_compute_instance" "webapp_instance" {
  name         = "webapp-instance"
  machine_type = "e2-medium"
  zone         = "us-east1-b"

  tags = ["webapp"]

  boot_disk {
    initialize_params {
      image = "${var.project_id}/csye6225-app-image"
      size  = 100
      type  = "pd-balanced"
    }
    mode = "READ_WRITE"
  }

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }
    network = google_compute_network.vpc.self_link

    subnetwork_project = var.project_id
    subnetwork         = google_compute_subnetwork.webapp_subnet.name
    stack_type         = "IPV4_ONLY"
  }

  depends_on = [google_compute_network.vpc]
}
