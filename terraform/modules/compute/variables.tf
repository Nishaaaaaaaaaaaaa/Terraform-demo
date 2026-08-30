variable "name" { type = string }
variable "environment" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "app_subnet_ids" { type = list(string) }
variable "alb_security_group_id" { type = string }
variable "ecs_security_group_id" { type = string }

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

  type = number

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
variable "database_url_secret_arn" {
  description = "Secrets Manager ARN whose value is the full DATABASE_URL."
  type        = string
}

variable "certificate_arn" {
  description = <<-EOT
    ACM certificate for the HTTPS listener. When empty the ALB serves plain HTTP
    on :80 — acceptable for a scratch environment, never for one holding real data.
  EOT
  type        = string
  default     = ""
}

variable "log_retention_days" {

  type = number

  default = 30

}
variable "enable_container_insights" {

  type = bool

  default = true

}
variable "enable_execute_command" {
  description = "Allow `aws ecs execute-command` into running tasks. Useful in dev, audited in prod."
  type        = bool
  default     = false
}

variable "otel_exporter_endpoint" {
  description = <<-EOT
    OTLP endpoint for application telemetry, e.g. http://signoz.internal:4318.
    Leave empty to run without instrumentation; the SDK is entirely env-driven,
    so an empty value simply disables export.
  EOT
  type        = string
  default     = ""
}

variable "deletion_protection" {

  type = bool

  default = true

}