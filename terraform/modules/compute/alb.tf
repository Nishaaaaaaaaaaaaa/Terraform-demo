# =============================================================================
# Application Load Balancer in the public subnets.
#
# Routing: /api/* and the API's own routes go to the server target group,
# everything else to the client. Both target groups are "ip" type because
# Fargate tasks have no instance to register.
# =============================================================================

resource "aws_lb" "this" {
  name               = substr("${var.name}-alb", 0, 32)
  load_balancer_type = "application"
  internal           = false
  subnets            = var.public_subnet_ids
  security_groups    = [var.alb_security_group_id]

  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection
  idle_timeout               = 60

  tags = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_lb_target_group" "server" {
  name        = substr("${var.name}-server", 0, 32)
  port        = var.server_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/healthz"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  # Let in-flight requests finish before a task is torn down on deploy.
  deregistration_delay = 30

  tags = merge(var.tags, { Name = "${var.name}-server" })

  lifecycle { create_before_destroy = true }
}

resource "aws_lb_target_group" "client" {
  name        = substr("${var.name}-client", 0, 32)
  port        = var.client_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = merge(var.tags, { Name = "${var.name}-client" })

  lifecycle { create_before_destroy = true }
}

# ---------------------------------------------------------------- listeners --
locals {
  https_enabled = var.certificate_arn != ""
}

# With a certificate, :80 only redirects. Without one, it serves the app.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.https_enabled ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.https_enabled ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.client.arn
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = local.https_enabled ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.client.arn
  }
}

# ------------------------------------------------------------------- rules ---
locals {
  # The reference API exposes these paths at the root rather than under /api.
  api_paths    = ["/api/*", "/users/*", "/user/*", "/healthz"]
  listener_arn = local.https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = local.listener_arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.server.arn
  }

  condition {
    path_pattern {
      values = local.api_paths
    }
  }

  tags = var.tags
}
