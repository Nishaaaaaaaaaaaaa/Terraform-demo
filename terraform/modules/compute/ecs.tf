# =============================================================================
# ECS on Fargate. Tasks run in the private app subnets with no public IP; all
# inbound traffic arrives through the ALB, all outbound leaves via NAT.
# =============================================================================

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"
  tags = var.tags

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

resource "aws_cloudwatch_log_group" "server" {
  name              = "/ecs/${var.name}/server"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "client" {
  name              = "/ecs/${var.name}/client"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

data "aws_region" "current" {}

locals {
  otel_env = var.otel_exporter_endpoint == "" ? [] : [
    { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = var.otel_exporter_endpoint },
    { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "http/protobuf" },
    { name = "OTEL_SERVICE_NAME", value = "${var.name}-server" },
    { name = "OTEL_RESOURCE_ATTRIBUTES", value = "service.namespace=${var.name},deployment.environment=${var.environment}" },
    { name = "OTEL_NODE_RESOURCE_DETECTORS", value = "env,host,os,process,container" },
  ]
}

# ------------------------------------------------------------------ server ---
resource "aws_ecs_task_definition" "server" {
  family                   = "${var.name}-server"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.server_cpu
  memory                   = var.server_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  tags                     = var.tags

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "server"
      image     = var.server_image
      essential = true

      portMappings = [
        { containerPort = var.server_port, protocol = "tcp" }
      ]

      # `migrate deploy` applies pending migrations without dropping anything.
      # Never use `migrate reset` here: it drops and reseeds the database on
      # every task start, which on a scaled service means repeatedly wiping
      # production data.
      command = ["sh", "-c", "npx prisma migrate deploy && npm start"]

      environment = concat(
        [
          { name = "NODE_ENV", value = var.environment },
          { name = "PORT", value = tostring(var.server_port) },
          { name = "LOG_LEVEL", value = "info" },
        ],
        local.otel_env,
      )

      secrets = [
        { name = "DATABASE_URL", valueFrom = var.database_url_secret_arn }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.server.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "server"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "node -e \"fetch('http://127.0.0.1:${var.server_port}/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\""]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

resource "aws_ecs_service" "server" {
  name            = "${var.name}-server"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.server.arn
  desired_count   = var.server_desired_count
  launch_type     = "FARGATE"

  enable_execute_command = var.enable_execute_command

  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.server.arn
    container_name   = "server"
    container_port   = var.server_port
  }

  # Keep full capacity during a deploy, and allow one extra task to start
  # before an old one is drained.
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  health_check_grace_period_seconds = 90

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags       = var.tags
  depends_on = [aws_lb_listener.http]

  lifecycle {
    # Let a CI pipeline or autoscaling change these without Terraform reverting.
    ignore_changes = [desired_count]
  }
}

# ------------------------------------------------------------------ client ---
resource "aws_ecs_task_definition" "client" {
  family                   = "${var.name}-client"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.client_cpu
  memory                   = var.client_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  tags                     = var.tags

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "client"
      image     = var.client_image
      essential = true

      portMappings = [
        { containerPort = var.client_port, protocol = "tcp" }
      ]

      command = ["sh", "-c", "npm run preview"]

      environment = [
        { name = "NODE_ENV", value = var.environment }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.client.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "client"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "client" {
  name            = "${var.name}-client"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.client.arn
  desired_count   = var.client_desired_count
  launch_type     = "FARGATE"

  enable_execute_command = var.enable_execute_command

  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.client.arn
    container_name   = "client"
    container_port   = var.client_port
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags       = var.tags
  depends_on = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [desired_count]
  }
}
