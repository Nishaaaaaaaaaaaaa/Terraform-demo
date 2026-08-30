variable "project" {
  type    = string
  default = "crudapp"
}
variable "environment" { type = string }
variable "region" { type = string }

variable "vpc_cidr" { type = string }
variable "az_count" {
  type    = number
  default = 2
}
variable "single_nat_gateway" {
  type    = bool
  default = true
}
variable "enable_interface_endpoints" {
  type    = bool
  default = false
}
variable "server_image" { type = string }
variable "client_image" { type = string }
variable "server_port" {
  type    = number
  default = 8000
}
variable "client_port" {
  type    = number
  default = 4173
}
variable "server_cpu" {

  type = number

  default = 512

}
variable "server_memory" {
  type    = number
  default = 1024
}
variable "client_cpu" {
  type    = number
  default = 256
}
variable "client_memory" {
  type    = number
  default = 512
}
variable "server_desired_count" {
  type    = number
  default = 2
}
variable "client_desired_count" {
  type    = number
  default = 2
}
variable "server_max_count" {
  type    = number
  default = 6
}
variable "client_max_count" {
  type    = number
  default = 4
}
variable "db_engine_version" {

  type = string

  default = "16.4"

}
variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "db_allocated_storage" {
  type    = number
  default = 20
}
variable "db_multi_az" {
  type    = bool
  default = false
}
variable "db_backup_retention_days" {
  type    = number
  default = 7
}
variable "db_name" {
  type    = string
  default = "docker_test_db"
}
variable "db_user" {
  type    = string
  default = "appuser"
}
variable "db_performance_insights" {
  type    = bool
  default = false
}
variable "db_monitoring_interval" {
  type    = number
  default = 0
}
variable "certificate_arn" {

  type = string

  default = ""

}
variable "alb_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
variable "waf_rate_limit_per_5min" {

  type = number

  default = 2000

}
variable "waf_blocked_countries" {
  type    = list(string)
  default = []
}
variable "waf_count_mode" {
  type    = bool
  default = false
}
variable "otel_exporter_endpoint" {

  type = string

  default = ""

}
variable "log_retention_days" {

  type = number

  default = 30

}
variable "enable_execute_command" {
  type    = bool
  default = false
}
variable "protect_resources" {
  description = <<-EOT
    Master switch for the guard rails: RDS deletion protection, a final snapshot,
    ALB deletion protection, and retention of ECR images on destroy.
    Set false only for environments you intend to tear down.
  EOT
  type        = bool
  default     = true
}

variable "extra_tags" {

  type = map(string)

  default = {}

}