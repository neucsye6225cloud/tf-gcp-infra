variable "project_id" {
  default = "csye6225-cloud-neu-414017"
}

variable "region" {
  default = "us-east1"
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

variable "subnet_cidr" {
  description = "CIDR block for the subnets"
  default     = "10.0.0.0/16"
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
