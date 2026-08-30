output "alb_dns_name" {
  description = "Public hostname of the load balancer."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "For a Route 53 alias record."
  value       = aws_lb.this.zone_id
}

output "alb_arn" { value = aws_lb.this.arn }

output "cluster_name" { value = aws_ecs_cluster.this.name }
output "cluster_arn" { value = aws_ecs_cluster.this.arn }

output "server_service_name" { value = aws_ecs_service.server.name }
output "client_service_name" { value = aws_ecs_service.client.name }

output "log_groups" {
  value = {
    server = aws_cloudwatch_log_group.server.name
    client = aws_cloudwatch_log_group.client.name
  }
}
