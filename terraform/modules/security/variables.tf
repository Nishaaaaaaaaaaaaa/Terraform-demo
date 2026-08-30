variable "name" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
variable "alb_ingress_cidrs" {
  description = <<-EOT
    Who may reach the load balancer. Defaults to the whole internet, which is
    right for a public app; narrow it to office/VPN ranges for an internal one.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "server_port" { type = number }
variable "client_port" { type = number }
