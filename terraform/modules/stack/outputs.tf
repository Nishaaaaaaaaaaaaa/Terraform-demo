output "application_url" {
  description = "Where the app is reachable once images are pushed and tasks are healthy."
  value       = var.certificate_arn == "" ? "http://${module.compute.alb_dns_name}" : "https://${module.compute.alb_dns_name}"
}

output "alb_dns_name" { value = module.compute.alb_dns_name }
output "alb_zone_id" { value = module.compute.alb_zone_id }

output "ecr_repository_urls" {
  description = "docker push targets."
  value       = module.ecr.repository_urls
}

output "ecs_cluster_name" { value = module.compute.cluster_name }
output "ecs_services" {
  value = {
    server = module.compute.server_service_name
    client = module.compute.client_service_name
  }
}

output "database_endpoint" { value = module.database.endpoint }
output "database_secret_arn" {
  description = "Credential JSON. Read with: aws secretsmanager get-secret-value --secret-id <arn>"
  value       = module.database.secret_arn
}

output "vpc_id" { value = module.network.vpc_id }
output "nat_public_ips" { value = module.network.nat_public_ips }

output "waf_web_acl_arn" { value = module.waf.web_acl_arn }
output "log_groups" { value = module.compute.log_groups }
