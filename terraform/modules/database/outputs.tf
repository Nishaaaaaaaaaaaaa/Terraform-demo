output "endpoint" { value = aws_db_instance.this.address }
output "port" { value = aws_db_instance.this.port }
output "db_name" { value = aws_db_instance.this.db_name }
output "instance_id" { value = aws_db_instance.this.identifier }

output "secret_arn" {
  description = "Secrets Manager ARN holding the credential JSON."
  value       = aws_secretsmanager_secret.db.arn
}

output "url_secret_arn" {
  description = "Secrets Manager ARN holding the full DATABASE_URL, injected into the task."
  value       = aws_secretsmanager_secret.db_url.arn
}
