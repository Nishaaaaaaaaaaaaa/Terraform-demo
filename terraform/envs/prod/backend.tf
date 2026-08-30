# Remote state. Create the bucket and lock table once with terraform/bootstrap,
# then uncomment and run: terraform init -migrate-state
#
# terraform {
#   backend "s3" {
#     bucket       = "<your-tfstate-bucket>"
#     key          = "crudapp/prod/terraform.tfstate"
#     region       = "ap-south-1"
#     encrypt      = true
#     use_lockfile = true
#   }
# }
