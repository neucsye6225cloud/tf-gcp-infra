# local variables
locals {
  timestamp     = formatdate("DDMMMYYYYhhmm", timestamp())
  db_host       = google_sql_database_instance.cloudsql_instance.ip_address[0].ip_address
  env_file_path = "/tmp/webapp/webapp.env"
}

# random password generator resource
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "#_"
}

resource "google_compute_network" "vpc" {
  name                            = var.vpc_name
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = true
}

resource "google_pubsub_topic" "verify_email" {
  name                       = var.pubsub_topic
  message_retention_duration = "86400s"
}

resource "google_compute_subnetwork" "webapp_subnet" {
  name          = var.webapp_subnet_name
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = var.webapp_subnet_cidr
  region        = var.region
}

resource "google_compute_subnetwork" "db_subnet" {
  name          = var.db_subnet_name
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = var.db_subnet_cidr
  region        = var.region
}

# a global address for private services access
resource "google_compute_global_address" "private_ip_range" {
  name          = var.psc_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  project       = var.project_id
  network       = google_compute_network.vpc.self_link
  prefix_length = 16
}

# a private services access connection
resource "google_service_networking_connection" "private_service_connection" {
  network                 = google_compute_network.vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
  depends_on              = [google_compute_global_address.private_ip_range]
}

resource "google_compute_route" "webapp_route" {
  name             = var.webapp_route_name
  network          = google_compute_network.vpc.self_link
  dest_range       = var.webapp_subnet_dest_range
  next_hop_gateway = "default-internet-gateway"
}

# firewall rule to block SSH traffic from the internet
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

# firewall rule for webapp subnet to allow traffic on a specific port
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

resource "google_service_account" "vm_service_account" {
  account_id   = "vm-service-account"
  display_name = "VM Service Account"
}

resource "google_project_iam_member" "logging_admin_binding" {
  project = var.project_id
  role    = "roles/logging.admin"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_project_iam_member" "monitoring_metric_writer_binding" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_project_iam_member" "cloud_sql_editor_binding" {
  project = var.project_id
  role    = "roles/cloudsql.editor"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

# a cloud SQL instance
resource "google_sql_database_instance" "cloudsql_instance" {
  database_version    = var.db_version
  region              = var.region
  project             = var.project_id
  deletion_protection = false

  settings {
    tier              = var.db_tier
    edition           = var.sql_db_instance_edition
    availability_type = var.sql_instance_availability_type
    disk_type         = var.sql_instance_disk_type
    disk_size         = var.sql_instance_disk_size

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.self_link
      #enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }
  }

  depends_on = [google_service_networking_connection.private_service_connection]
}

# create a database in cloud sql instance
resource "google_sql_database" "database" {
  name     = "webapp-${local.timestamp}"
  instance = google_sql_database_instance.cloudsql_instance.name
}

# create a user in cloud sql database with randomly generated password
resource "google_sql_user" "db_user" {
  name     = "webapp"
  instance = google_sql_database_instance.cloudsql_instance.name
  password = random_password.password.result
  project  = var.project_id
}

# Compute Engine instance (VM)
resource "google_compute_instance" "webapp_instance" {
  name         = "webapp-instance"
  machine_type = var.compute_instance_machine_type
  zone         = var.compute_instance_zone

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
      // network_tier = "PREMIUM"
    }
    network = google_compute_network.vpc.self_link

    subnetwork_project = var.project_id
    subnetwork         = google_compute_subnetwork.webapp_subnet.name
    stack_type         = "IPV4_ONLY"
  }

  metadata_startup_script = <<EOF
  #!/bin/bash
  touch ${local.env_file_path}
  echo "DB_HOST=${local.db_host}" >> ${local.env_file_path}
  echo "DB_PORT=3306" >> ${local.env_file_path}
  echo "DB_NAME=${google_sql_database.database.name}" >> ${local.env_file_path}
  echo "DB_USER=${google_sql_user.db_user.name}" >> ${local.env_file_path}
  echo "DB_PASSWORD=${random_password.password.result}" >> ${local.env_file_path}
  echo "PROJECT_ID=${var.project_id}" >> ${local.env_file_path}
  echo "SQL_INSTANCE=${google_sql_database_instance.cloudsql_instance.name}" >> ${local.env_file_path}
  echo "PUBSUB_TOPIC=${google_pubsub_topic.verify_email.name}" >> ${local.env_file_path}
  sudo chown -R csye6225:csye6225 /tmp/webapp/webapp.env
  sudo chmod 644 /tmp/webapp/webapp.env

  # indicator file to indicate the success of the startup script
  touch /tmp/success-indicator-file
  sudo systemctl restart csye6225.service

  EOF

  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"]
  }

  depends_on = [google_compute_network.vpc, google_service_account.vm_service_account]
}

resource "google_dns_record_set" "a" {
  name         = var.domain_name
  type         = "A"
  ttl          = 300
  managed_zone = var.dns_managed_zone

  rrdatas = [google_compute_instance.webapp_instance.network_interface[0].access_config[0].nat_ip]
}




resource "google_pubsub_subscription" "email_verification" {
  name  = "email-verification"
  topic = google_pubsub_topic.verify_email.id

  message_retention_duration = "120s"
  retain_acked_messages      = true

  ack_deadline_seconds = 20

  retry_policy {
    minimum_backoff = "10s"
  }
  project                 = var.project_id
  enable_message_ordering = false
}

resource "google_pubsub_topic_iam_binding" "binding" {
  project = var.project_id
  topic   = google_pubsub_topic.verify_email.name
  role    = "roles/viewer"
  members = [
    "serviceAccount:${google_service_account.vm_service_account.email}",
  ]
}

resource "google_vpc_access_connector" "connector" {
  name           = "vpc-connector"
  region         = var.region
  network        = google_compute_network.vpc.self_link
  ip_cidr_range  = var.gcf_cidr_range
  min_throughput = 200
  max_throughput = 300
}

resource "google_cloudfunctions2_function" "default" {
  name        = "sendVerificationEmail"
  location    = var.region
  description = "a new function"

  build_config {
    runtime     = "python39"
    entry_point = "send_email"
    # environment_variables = {
    #   BUILD_CONFIG_TEST = "build_test"
    # }
    source {
      storage_source {
        bucket = var.bucket_name
        object = var.object_name
      }
    }
  }

  service_config {
    max_instance_count = 1
    min_instance_count = 0
    available_memory   = "256M"
    timeout_seconds    = 60

    environment_variables = {
      SERVICE_CONFIG_TEST = "config_test"
      MAILGUN_API_KEY     = "${var.mailgun_api_key}"
      MAILGUN_DOMAIN      = "${var.mailgun_domain}"
      HOST                = "${google_sql_database_instance.cloudsql_instance.ip_address[0]}"
      DB_USER             = "${google_sql_user.db_user.name}"
      DB_PASSWORD         = "${random_password.password.result}"
      DATABASE            = "${google_sql_database.database.name}"
    }
    vpc_connector = google_vpc_access_connector.connector.id
    # ingress_settings               = "ALLOW_INTERNAL_ONLY"
    # all_traffic_on_latest_revision = true
    service_account_email = google_service_account.vm_service_account.email
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.verify_email.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}



output "db_host" {
  value       = google_sql_database_instance.cloudsql_instance.ip_address[0]
  description = "IP address of the host running the Cloud SQL Database."
}

output "nat_ip" {
  value       = google_compute_instance.webapp_instance.network_interface[0].access_config[0].nat_ip
  description = "The public IP address of the webapp instance."
}
