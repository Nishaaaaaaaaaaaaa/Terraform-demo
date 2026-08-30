output "vpc_id" { value = aws_vpc.this.id }
output "vpc_cidr" { value = aws_vpc.this.cidr_block }

output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "app_subnet_ids" { value = aws_subnet.app[*].id }
output "data_subnet_ids" { value = aws_subnet.data[*].id }

output "app_subnet_cidrs" { value = local.app_cidrs }
output "availability_zones" { value = local.azs }

output "nat_public_ips" {
  description = "Stable egress IPs — the addresses to allowlist on any third party."
  value       = aws_eip.nat[*].public_ip
}
