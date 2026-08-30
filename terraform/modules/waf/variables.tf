variable "name" { type = string }
variable "environment" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
variable "alb_arn" {
  description = "ARN of the load balancer to associate the web ACL with."
  type        = string
}

variable "rate_limit_per_5min" {
  description = "Requests from a single IP in a 5-minute window before it is blocked."
  type        = number
  default     = 2000
}

variable "blocked_countries" {
  description = "ISO 3166-1 alpha-2 codes to block outright. Empty disables the rule."
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "count_mode" {
  description = <<-EOT
    true  -> managed rules only count matches instead of blocking.
    Run a new environment in count mode for a few days, review the sampled
    requests, add exclusions for anything legitimate, then switch to blocking.
  EOT
  type        = bool
  default     = false
}
