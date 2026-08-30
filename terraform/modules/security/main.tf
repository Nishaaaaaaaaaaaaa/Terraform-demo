# =============================================================================
# Security groups — a strict chain, each rule referencing the group before it
# rather than a CIDR:
#
#   internet --> alb --> ecs tasks --> rds
#
# Referencing groups instead of CIDRs means the rules stay correct when subnets
# change, and nothing in the app tier is reachable except from the load balancer.
# =============================================================================

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Public entry point. HTTP/HTTPS in, app tier out."
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-alb" })

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each          = toset(var.alb_ingress_cidrs)
  security_group_id = aws_security_group.alb.id
  description       = "HTTP (redirected to HTTPS when a certificate is configured)"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each          = toset(var.alb_ingress_cidrs)
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_server" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward to the API containers"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = var.server_port
  to_port                      = var.server_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_client" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward to the web containers"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = var.client_port
  to_port                      = var.client_port
  ip_protocol                  = "tcp"
}

# ------------------------------------------------------------------- tasks ---
resource "aws_security_group" "ecs" {
  name        = "${var.name}-ecs-tasks"
  description = "Fargate tasks. Inbound only from the ALB."
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-ecs-tasks" })

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb_server" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "API port, from the load balancer only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.server_port
  to_port                      = var.server_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb_client" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Web port, from the load balancer only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.client_port
  to_port                      = var.client_port
  ip_protocol                  = "tcp"
}

# Egress is open: tasks need ECR, CloudWatch Logs, Secrets Manager and possibly
# an OTLP collector. Narrow this to VPC endpoints if you enable them and want to
# remove internet egress entirely.
resource "aws_vpc_security_group_egress_rule" "ecs_all" {
  security_group_id = aws_security_group.ecs.id
  description       = "Outbound to AWS APIs and the internet via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# -------------------------------------------------------------------- rds ----
resource "aws_security_group" "rds" {
  name        = "${var.name}-rds"
  description = "PostgreSQL. Reachable only from the task security group."
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-rds" })

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from the application tasks"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# No egress rule. RDS never needs to originate a connection, and omitting it
# leaves the group with no egress at all.
