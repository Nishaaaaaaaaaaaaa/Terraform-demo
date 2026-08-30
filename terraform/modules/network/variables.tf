variable "name" {
  description = "Name prefix for every resource, e.g. crudapp-dev."
  type        = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vpc_cidr" {
  description = "CIDR for the VPC. A /16 leaves room for the /24 subnet tiers below."
  type        = string
}

variable "az_count" {
  description = "Number of availability zones to spread the three subnet tiers across."
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

variable "single_nat_gateway" {
  description = <<-EOT
    true  -> one NAT gateway shared by every private subnet (cheap, single AZ failure domain)
    false -> one NAT gateway per AZ (resilient, ~$32/AZ/month more)
    Use true for dev/staging, false for prod.
  EOT
  type        = bool
  default     = true
}

variable "enable_interface_endpoints" {
  description = <<-EOT
    Create interface VPC endpoints for ECR, CloudWatch Logs and Secrets Manager so ECS
    tasks pull images and write logs without traversing NAT. Each endpoint costs about
    $7/month per AZ but removes NAT data-processing charges, which usually wins once
    image pulls are frequent.
  EOT
  type        = bool
  default     = false
}

variable "flow_log_retention_days" {
  type    = number
  default = 30
}
