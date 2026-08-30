# ------------------------------------------------------------- staging -----
# Production-shaped, production-sized-down. The place to catch anything that
# only appears with real guard rails switched on.

region   = "ap-south-1"
vpc_cidr = "10.20.0.0/16"
az_count = 2

single_nat_gateway         = true
enable_interface_endpoints = false

server_image = "<account-id>.dkr.ecr.ap-south-1.amazonaws.com/crudapp-staging/server:latest"
client_image = "<account-id>.dkr.ecr.ap-south-1.amazonaws.com/crudapp-staging/client:latest"

server_cpu           = 512
server_memory        = 1024
client_cpu           = 256
client_memory        = 512
server_desired_count = 2
client_desired_count = 2
server_max_count     = 4
client_max_count     = 3

db_instance_class        = "db.t4g.small"
db_allocated_storage     = 20
db_multi_az              = false
db_backup_retention_days = 7
db_performance_insights  = true

# Point at an ACM certificate in this region to get HTTPS and the :80 redirect.
certificate_arn = ""

waf_count_mode          = false
waf_rate_limit_per_5min = 2000

log_retention_days     = 30
enable_execute_command = true
protect_resources      = true

extra_tags = {
  CostCenter = "engineering"
  Owner      = "platform"
}
