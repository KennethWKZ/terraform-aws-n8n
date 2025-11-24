locals {
  # Base environment variables for n8n container
  n8n_base_environment = [
    {
      name  = "NODE_ENV"
      value = "development"
    },
    {
      name  = "GENERIC_TIMEZONE"
      value = "Asia/Kuala_Lumpur"
    },
    {
      name  = "WEBHOOK_URL"
      value = var.url != null ? var.url : (var.route53_zone_id != null && var.route53_record_name != null ? "${var.certificate_arn == null ? "http" : "https"}://${var.route53_record_name}.${trimprefix(data.aws_route53_zone.main[0].name, ".")}/" : "${var.certificate_arn == null ? "http" : "https"}://${aws_lb.main.dns_name}/")
    },
    {
      name  = "N8N_PROTOCOL"
      value = "https"
    },
    {
      name  = "N8N_HOST"
      value = "0.0.0.0"
    },
    {
      name  = "N8N_ENTERPRISE_MOCK"
      value = "true"
    },
    {
      name  = "N8N_MULTI_MAIN_SETUP_ENABLED"
      value = "true"
    },
    {
      name  = "N8N_SKIP_WEBHOOK_DEREGISTRATION_SHUTDOWN"
      value = "true"
    },
    {
      name  = "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS"
      value = "true"
    },
    {
      name  = "N8N_EXTERNAL_STORAGE_S3_HOST"
      value = "s3.ap-southeast-1.amazonaws.com"
    },
    {
      name  = "N8N_EXTERNAL_STORAGE_S3_BUCKET_NAME"
      value = aws_s3_bucket.n8n_binary_data.id
    },
    {
      name  = "N8N_AVAILABLE_BINARY_DATA_MODES"
      value = "s3"
    },
    {
      name  = "N8N_EXTERNAL_STORAGE_S3_AUTH_AUTO_DETECT"
      value = "true"
    },
    {
      name  = "N8N_DEFAULT_BINARY_DATA_MODE"
      value = "s3"
    },
    {
      name  = "QUEUE_BULL_REDIS_ELASTICACHE_SERVERLESS"
      value = "true"
    },
    {
      name  = "QUEUE_BULL_REDIS_CLUSTER_NODES"
      value = "${aws_elasticache_serverless_cache.valkey.endpoint[0].address}:${aws_elasticache_serverless_cache.valkey.endpoint[0].port}"
    },
    {
      name  = "QUEUE_BULL_REDIS_TLS"
      value = "true"
    },
    {
      name  = "QUEUE_BULL_REDIS_USERNAME"
      value = aws_elasticache_user.valkey.user_name
    },
    {
      name  = "EXECUTIONS_MODE"
      value = "queue"
    },
    {
      name  = "DB_TYPE"
      value = "postgresdb"
    },
    {
      name  = "DB_POSTGRESDB_HOST"
      value = aws_rds_cluster.aurora.endpoint
    },
    {
      name  = "DB_POSTGRESDB_PORT"
      value = "5432"
    },
    {
      name  = "DB_POSTGRESDB_DATABASE"
      value = var.db_name
    },
    {
      name  = "DB_POSTGRESDB_SSL_ENABLED"
      value = "true"
    },
    {
      name  = "DB_POSTGRESDB_SSL_CA_FILE"
      value = "/usr/local/share/ca-certificates/aws-rds-combined-ca-bundle.pem"
    },
    {
      name  = "DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED"
      value = "true"
    },
    {
      name  = "DB_POSTGRESDB_USER"
      value = var.db_master_username
    },
    {
      name  = "N8N_HIRING_BANNER_ENABLED"
      value = "false"
    },
    {
      name  = "N8N_SSO_SAML_LOGIN_LABEL"
      value = "MoneyMatch n8n"
    },
    {
      name  = "N8N_SSO_SCOPES_PROVISION_INSTANCE_ROLE"
      value = "true"
    },
    {
      name  = "N8N_SSO_SCOPES_PROVISION_PROJECT_ROLES"
      value = "true"
    },
    {
      name  = "N8N_SSO_JUST_IN_TIME_PROVISIONING"
      value = "true"
    },
    {
      name  = "N8N_BLOCK_FILE_ACCESS_TO_N8N_FILES"
      value = "true"
    },
    {
      name  = "N8N_INVITE_LINKS_EMAIL_ONLY"
      value = "true"
    },
    {
      name  = "N8N_PUBLIC_API_DISABLED"
      value = "true"
    },
    {
      name  = "N8N_PUBLIC_API_SWAGGERUI_DISABLED"
      value = "true"
    },
    {
      name  = "N8N_DIAGNOSTICS_ENABLED"
      value = "false"
    },
    {
      name  = "N8N_VERSION_NOTIFICATIONS_ENABLED"
      value = "false"
    },
    {
      name  = "N8N_LOG_LEVEL"
      value = "debug"
    }
  ]

  # SMTP environment variables (only added when SMTP is configured)
  n8n_smtp_environment = [
    {
      name  = "N8N_EMAIL_MODE"
      value = "smtp"
    },
    {
      name  = "N8N_SMTP_HOST"
      value = var.smtp_host
    },
    {
      name  = "N8N_SMTP_PORT"
      value = tostring(var.smtp_port)
    },
    {
      name  = "N8N_SMTP_USER"
      value = var.smtp_user
    },
    {
      name  = "N8N_SMTP_PASS"
      value = var.smtp_pass
    },
    {
      name  = "N8N_SMTP_SENDER"
      value = var.smtp_sender
    },
    {
      name  = "N8N_SMTP_SSL"
      value = tostring(var.smtp_ssl)
    }
  ]

  # Main instance environment overrides
  main_environment_overrides = [
    {
      name  = "N8N_CONCURRENCY_PRODUCTION_LIMIT"
      value = tostring(var.main_concurrency)
    },
    {
      name  = "DB_POSTGRESDB_POOL_SIZE"
      value = tostring(var.main_pool_size)
    }
  ]

  # Worker instance environment overrides
  worker_environment_overrides = [
    {
      name  = "N8N_CONCURRENCY_PRODUCTION_LIMIT"
      value = tostring(var.worker_concurrency)
    },
    {
      name  = "DB_POSTGRESDB_POOL_SIZE"
      value = tostring(var.worker_pool_size)
    }
  ]
}

resource "aws_ecs_cluster" "ecs" {
  name = "${var.prefix}-cluster"
  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = var.tags
}

# Service Discovery namespace for internal service communication
resource "aws_service_discovery_private_dns_namespace" "internal" {
  name        = "${var.prefix}.local"
  description = "Private DNS namespace for ${var.prefix} services"
  vpc         = local.vpc_id

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.ecs.name
  capacity_providers = [var.fargate_type]
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = var.fargate_type
  }
}

resource "aws_cloudwatch_log_group" "logs" {
  name              = "${var.prefix}-logs"
  retention_in_days = 180

  tags = var.tags
}

# Worker CloudWatch log group
resource "aws_cloudwatch_log_group" "worker_logs" {
  name              = "${var.prefix}-worker-logs"
  retention_in_days = 180

  tags = var.tags
}

# Browserless CloudWatch log group
resource "aws_cloudwatch_log_group" "browserless" {
  count             = var.browserless_enabled ? 1 : 0
  name              = "${var.prefix}-browserless-logs"
  retention_in_days = 180

  tags = var.tags
}

resource "aws_ecs_task_definition" "taskdef" {
  family             = "${var.prefix}-taskdef"
  task_role_arn      = aws_iam_role.taskrole.arn
  execution_role_arn = aws_iam_role.executionrole.arn
  container_definitions = jsonencode([
    {
      name      = "n8n"
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = 5678
          hostPort      = 5678
          protocol      = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "persistent"
          containerPath = "/home/node/.n8n"
          readOnly      = false
        }
      ]
      # Conditionally add SMTP configuration if smtp_host is provided
      environment = var.smtp_host != null ? concat(
        local.n8n_base_environment,
        local.n8n_smtp_environment,
        local.main_environment_overrides
      ) : concat(
        local.n8n_base_environment,
        local.main_environment_overrides
      )
      secrets = [
        {
          name      = "DB_POSTGRESDB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::"
        },
        {
          name      = "QUEUE_BULL_REDIS_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.valkey_credentials.arn}:password::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.logs.name
          awslogs-region        = data.aws_region.current.id
          awslogs-stream-prefix = "n8n"
        }
      }
    }
  ])
  volume {
    name = "persistent"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.main.id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.access.id
        iam             = "ENABLED"
      }
    }
  }
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
  cpu    = 1024
  memory = 2048

  tags = var.tags
}

# Worker task definition - processes queued executions
resource "aws_ecs_task_definition" "worker" {
  family             = "${var.prefix}-worker-taskdef"
  task_role_arn      = aws_iam_role.taskrole.arn
  execution_role_arn = aws_iam_role.executionrole.arn
  container_definitions = jsonencode([
    {
      name      = "n8n-worker"
      image     = var.container_image
      essential = true
      command   = ["worker"]
      mountPoints = [
        {
          sourceVolume  = "persistent"
          containerPath = "/home/node/.n8n"
          readOnly      = false
        }
      ]
      # Worker-specific environment with concurrency limit override
      environment = var.smtp_host != null ? concat(
        local.n8n_base_environment,
        local.n8n_smtp_environment,
        local.worker_environment_overrides
      ) : concat(
        local.n8n_base_environment,
        local.worker_environment_overrides
      )
      secrets = [
        {
          name      = "DB_POSTGRESDB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.db_credentials.arn}:password::"
        },
        {
          name      = "QUEUE_BULL_REDIS_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.valkey_credentials.arn}:password::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.worker_logs.name
          awslogs-region        = data.aws_region.current.id
          awslogs-stream-prefix = "n8n-worker"
        }
      }
    }
  ])
  volume {
    name = "persistent"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.main.id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.access.id
        iam             = "ENABLED"
      }
    }
  }
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
  cpu    = var.worker_cpu
  memory = var.worker_memory

  tags = var.tags
}

# Browserless task definition
resource "aws_ecs_task_definition" "browserless" {
  count              = var.browserless_enabled ? 1 : 0
  family             = "${var.prefix}-browserless-taskdef"
  execution_role_arn = aws_iam_role.executionrole.arn
  container_definitions = jsonencode([
    {
      name      = "browserless"
      image     = var.browserless_container_image
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "TOKEN"
          value = var.browserless_token
        },
        {
          name  = "CONCURRENT"
          value = tostring(var.browserless_max_concurrent_sessions)
        },
        {
          name  = "TIMEOUT"
          value = tostring(var.browserless_timeout)
        },
        {
          name  = "ENABLE_DEBUGGER"
          value = "false"
        },
        {
          name  = "CORS"
          value = "true"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.browserless[0].name
          awslogs-region        = data.aws_region.current.id
          awslogs-stream-prefix = "browserless"
        }
      }
    }
  ])
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
  cpu    = var.browserless_cpu
  memory = var.browserless_memory

  tags = var.tags
}

resource "aws_security_group" "n8n" {
  name   = "${var.prefix}-sg"
  vpc_id = local.vpc_id
  ingress {
    from_port = 5678
    to_port   = 5678
    protocol  = "tcp"
    security_groups = [
      aws_security_group.alb.id
    ]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = var.tags
}

# Browserless security group
resource "aws_security_group" "browserless" {
  count  = var.browserless_enabled ? 1 : 0
  name   = "${var.prefix}-browserless-sg"
  vpc_id = local.vpc_id
  
  ingress {
    description = "WebSocket access from n8n"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    security_groups = [
      aws_security_group.n8n.id
    ]
  }
  
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.prefix}-browserless-sg"
    }
  )
}

resource "aws_ecs_service" "service" {
  name                   = "${var.prefix}-service"
  cluster                = aws_ecs_cluster.ecs.id
  task_definition        = aws_ecs_task_definition.taskdef.arn
  desired_count          = var.desired_count
  force_new_deployment   = var.n8n_force_new_deployment

  triggers = {
    redeployment = plantimestamp()
  }

  capacity_provider_strategy {
    capacity_provider = var.fargate_type
    weight            = 100
    base              = 1
  }
  network_configuration {
    subnets = local.ecs_subnets
    security_groups = [
      aws_security_group.n8n.id
    ]
    # Only assign public IP when using public subnets
    # Private subnets should route through NAT Gateway for internet access
    assign_public_ip = !var.use_private_subnets && length(var.subnet_ids) == 0
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.ip.arn
    container_name   = "n8n"
    container_port   = 5678
  }

  tags = var.tags
}

# Worker ECS service - processes queued executions (no ALB needed)
resource "aws_ecs_service" "worker" {
  name                   = "${var.prefix}-worker-service"
  cluster                = aws_ecs_cluster.ecs.id
  task_definition        = aws_ecs_task_definition.worker.arn
  desired_count          = var.worker_desired_count
  force_new_deployment   = var.n8n_force_new_deployment

  triggers = {
    redeployment = plantimestamp()
  }

  capacity_provider_strategy {
    capacity_provider = var.fargate_type
    weight            = 100
    base              = 1
  }
  network_configuration {
    subnets = local.ecs_subnets
    security_groups = [
      aws_security_group.n8n.id
    ]
    # Only assign public IP when using public subnets
    assign_public_ip = !var.use_private_subnets && length(var.subnet_ids) == 0
  }

  tags = var.tags
}

# Service Discovery service for browserless
resource "aws_service_discovery_service" "browserless" {
  count = var.browserless_enabled ? 1 : 0
  name  = "browserless"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  tags = var.tags
}

# Browserless ECS service with Service Discovery
resource "aws_ecs_service" "browserless" {
  count                = var.browserless_enabled ? 1 : 0
  name                 = "${var.prefix}-browserless-service"
  cluster              = aws_ecs_cluster.ecs.id
  task_definition      = aws_ecs_task_definition.browserless[0].arn
  desired_count        = var.browserless_desired_count
  force_new_deployment = var.browserless_force_new_deployment

  triggers = {
    redeployment = plantimestamp()
  }
  
  capacity_provider_strategy {
    capacity_provider = var.fargate_type
    weight            = 100
    base              = 1
  }
  
  network_configuration {
    subnets = local.ecs_subnets
    security_groups = [
      aws_security_group.browserless[0].id
    ]
    # Only assign public IP when using public subnets
    assign_public_ip = !var.use_private_subnets && length(var.subnet_ids) == 0
  }
  
  service_registries {
    registry_arn = aws_service_discovery_service.browserless[0].arn
  }

  tags = var.tags
}
