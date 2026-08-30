# =============================================================================
# The whole stack for one environment. Every env/ directory is a thin wrapper
# around this module with different variable values, so dev, staging and prod
# stay structurally identical and only differ in sizing and guard rails.
# =============================================================================

locals {
  name = "${var.project}-${var.environment}"

  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Stack       = "crudapp-ecs"
    },
    var.extra_tags,
  )
}

module "network" {
  source = "../network"

  name                       = local.name
  environment                = var.environment
  vpc_cidr                   = var.vpc_cidr
  az_count                   = var.az_count
  single_nat_gateway         = var.single_nat_gateway
  enable_interface_endpoints = var.enable_interface_endpoints
  flow_log_retention_days    = var.log_retention_days
  tags                       = local.tags
}

module "security" {
  source = "../security"

  name              = local.name
  vpc_id            = module.network.vpc_id
  vpc_cidr          = module.network.vpc_cidr
  alb_ingress_cidrs = var.alb_ingress_cidrs
  server_port       = var.server_port
  client_port       = var.client_port
  tags              = local.tags
}

module "ecr" {
  source = "../ecr"

  name         = local.name
  repositories = ["server", "client"]
  force_delete = !var.protect_resources
  tags         = local.tags
}

module "database" {
  source = "../database"

  name        = local.name
  environment = var.environment

  subnet_ids        = module.network.data_subnet_ids
  security_group_id = module.security.rds_security_group_id

  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  db_name               = var.db_name
  db_user               = var.db_user

  deletion_protection          = var.protect_resources
  skip_final_snapshot          = !var.protect_resources
  performance_insights_enabled = var.db_performance_insights
  monitoring_interval          = var.db_monitoring_interval

  tags = local.tags
}

module "compute" {
  source = "../compute"

  name        = local.name
  environment = var.environment

  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  app_subnet_ids        = module.network.app_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  ecs_security_group_id = module.security.ecs_security_group_id

  server_image = var.server_image
  client_image = var.client_image
  server_port  = var.server_port
  client_port  = var.client_port

  server_cpu           = var.server_cpu
  server_memory        = var.server_memory
  client_cpu           = var.client_cpu
  client_memory        = var.client_memory
  server_desired_count = var.server_desired_count
  client_desired_count = var.client_desired_count
  server_max_count     = var.server_max_count
  client_max_count     = var.client_max_count

  database_url_secret_arn = module.database.url_secret_arn

  certificate_arn        = var.certificate_arn
  otel_exporter_endpoint = var.otel_exporter_endpoint
  log_retention_days     = var.log_retention_days
  enable_execute_command = var.enable_execute_command
  deletion_protection    = var.protect_resources

  tags = local.tags
}

module "waf" {
  source = "../waf"

  name                = local.name
  environment         = var.environment
  alb_arn             = module.compute.alb_arn
  rate_limit_per_5min = var.waf_rate_limit_per_5min
  blocked_countries   = var.waf_blocked_countries
  count_mode          = var.waf_count_mode
  log_retention_days  = var.log_retention_days
  tags                = local.tags
}
