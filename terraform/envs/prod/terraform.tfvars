# ---------------------------------------------------------------- prod -----
# Every guard rail on. Multi-AZ everywhere that supports it.

region   = "ap-south-1"
vpc_cidr = "10.30.0.0/16"
az_count = 3

# A NAT gateway per AZ: an AZ outage must not take egress with it.
single_nat_gateway = false
# Interface endpoints pay for themselves once image pulls are frequent, and
# keep ECR/logs/secrets traffic off the public internet entirely.
enable_interface_endpoints = true

# Pin an immutable tag in production. `:latest` makes rollbacks guesswork and
# means two tasks can silently run different code.
server_image = "<account-id>.dkr.ecr.ap-south-1.amazonaws.com/crudapp-prod/server:v1.0.0"
client_image = "<account-id>.dkr.ecr.ap-south-1.amazonaws.com/crudapp-prod/client:v1.0.0"

server_cpu           = 1024
server_memory        = 2048
client_cpu           = 512
client_memory        = 1024
server_desired_count = 3
client_desired_count = 2
server_max_count     = 12
client_max_count     = 6

db_instance_class        = "db.t4g.medium"
db_allocated_storage     = 50
db_multi_az              = true
db_backup_retention_days = 30
db_performance_insights  = true
db_monitoring_interval   = 60

# REQUIRED before this carries real traffic. Without it the ALB serves plain
# HTTP and the database password crosses the internet in every API call.
certificate_arn = ""

waf_count_mode          = false
waf_rate_limit_per_5min = 2000
waf_blocked_countries   = []

log_retention_days = 90

# No interactive shells into production tasks by default.
enable_execute_command = false

protect_resources = true

extra_tags = {
  CostCenter = "engineering"
  Owner      = "platform"
  Compliance = "in-scope"
}
