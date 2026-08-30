# =============================================================================
# dev environment. Thin wrapper around modules/stack — everything that differs
# between environments lives in terraform.tfvars, not here.
# =============================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

module "stack" {
  source = "../../modules/stack"

  project     = var.project
  environment = "dev"
  region      = var.region

  vpc_cidr                   = var.vpc_cidr
  az_count                   = var.az_count
  single_nat_gateway         = var.single_nat_gateway
  enable_interface_endpoints = var.enable_interface_endpoints

  server_image = var.server_image
  client_image = var.client_image

  server_cpu           = var.server_cpu
  server_memory        = var.server_memory
  client_cpu           = var.client_cpu
  client_memory        = var.client_memory
  server_desired_count = var.server_desired_count
  client_desired_count = var.client_desired_count
  server_max_count     = var.server_max_count
  client_max_count     = var.client_max_count

  db_instance_class        = var.db_instance_class
  db_allocated_storage     = var.db_allocated_storage
  db_multi_az              = var.db_multi_az
  db_backup_retention_days = var.db_backup_retention_days
  db_performance_insights  = var.db_performance_insights
  db_monitoring_interval   = var.db_monitoring_interval
  db_name                  = var.db_name
  db_user                  = var.db_user

  certificate_arn   = var.certificate_arn
  alb_ingress_cidrs = var.alb_ingress_cidrs

  waf_rate_limit_per_5min = var.waf_rate_limit_per_5min
  waf_blocked_countries   = var.waf_blocked_countries
  waf_count_mode          = var.waf_count_mode

  otel_exporter_endpoint = var.otel_exporter_endpoint
  log_retention_days     = var.log_retention_days
  enable_execute_command = var.enable_execute_command
  protect_resources      = var.protect_resources
  extra_tags             = var.extra_tags
}
