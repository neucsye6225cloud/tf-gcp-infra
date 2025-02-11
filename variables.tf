variable "project_id" {
  default = "csye6225-cloud-dev-414620"
}

variable "region" {
  default = "us-central1"
}

variable "vpc_name" {
  description = "csye6225_terraform_network"
}

variable "routing_mode" {
  description = "REGIONAL"
}

variable "webapp_subnet_name" {
  description = "webapp"
}

variable "db_subnet_name" {
  description = "db"
}

variable "webapp_subnet_cidr" {
  description = "CIDR block for the webapp subnet"
}

variable "db_subnet_cidr" {
  description = "CIDR block for the db subnet"
}

variable "webapp_subnet_dest_range" {
  description = "route destination for webapp subnet"
}

variable "webapp_route_name" {
  description = "name of route to webapp subnet"
}

variable "delete_default_route_name" {
  description = "name of route to delete default route"
}

variable "psc_name" {}
variable "sql_instance_name" {}
variable "db_tier" {}
variable "db_version" {}
variable "compute_instance_zone" {}
variable "compute_instance_machine_type" {}
variable "sql_db_instance_edition" {}
variable "sql_instance_availability_type" {}
variable "sql_instance_disk_type" {}
variable "sql_instance_disk_size" {}
variable "domain_name" {}
variable "dns_managed_zone" {}
variable "gcf_cidr_range" {}
variable "bucket_name" {}
variable "object_name" {}
variable "mailgun_api_key" {}
variable "pubsub_topic" {}
variable "mailgun_domain" {}
variable "compute_health_check_name" {}
variable "backend_protocol" {}
variable "igm_port_name" {}
variable "key_rotation_period" {}
