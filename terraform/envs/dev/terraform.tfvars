# ---------------------------------------------------------------- dev -------
# Cheapest shape that still exercises the full architecture. Disposable.

region   = "ap-south-1"
vpc_cidr = "10.10.0.0/16"
az_count = 2

# One NAT gateway instead of two: saves ~$32/month, costs you an AZ failure domain.
single_nat_gateway         = true
enable_interface_endpoints = false

# Replace <account-id> after the first apply — `terraform output ecr_repository_urls`
# prints the exact values.
server_image = "<account-id>.dkr.ecr.ap-south-1.amazonaws.com/crudapp-dev/server:latest"
client_image = "<account-id>.dkr.ecr.ap-south-1.amazonaws.com/crudapp-dev/client:latest"

server_cpu           = 256
server_memory        = 512
client_cpu           = 256
client_memory        = 512
server_desired_count = 1
client_desired_count = 1
server_max_count     = 2
client_max_count     = 2

db_instance_class        = "db.t4g.micro"
db_allocated_storage     = 20
db_multi_az              = false
db_backup_retention_days = 1

# Plain HTTP. Fine for a scratch environment; never for one holding real data.
certificate_arn = ""

# Count mode first: watch what the managed rules would have blocked before
# letting them block anything.
waf_count_mode          = true
waf_rate_limit_per_5min = 5000

log_retention_days     = 7
enable_execute_command = true # shell into tasks while debugging

# Lets `terraform destroy` actually succeed.
protect_resources = false

extra_tags = {
  CostCenter = "engineering"
  Owner      = "platform"
}
