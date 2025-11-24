# ElastiCache Valkey for n8n queue mode
# This enables distributed operation of multiple n8n containers

# Generate random password for Valkey user
resource "random_password" "valkey_password" {
  length  = 32
  special = true
  # ElastiCache password requirements: 16-128 printable ASCII characters except @, ", and /
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store Valkey user credentials in Secrets Manager
resource "aws_secretsmanager_secret" "valkey_credentials" {
  name                    = "${var.prefix}-valkey-credentials"
  description             = "Valkey user credentials for n8n ElastiCache"
  recovery_window_in_days = var.db_secret_recovery_days

  tags = {
    Name = "${var.prefix}-valkey-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "valkey_credentials" {
  secret_id = aws_secretsmanager_secret.valkey_credentials.id
  secret_string = jsonencode({
    username = aws_elasticache_user.valkey.user_name
    password = random_password.valkey_password.result
  })
}

# ElastiCache User for Valkey serverless
# Serverless mode requires user group access control instead of AUTH tokens
resource "aws_elasticache_user" "valkey" {
  user_id       = "${var.prefix}-valkey-admin"
  user_name     = "n8n-valkey-admin"
  access_string = "on ~* +@all"
  engine        = "valkey"

  authentication_mode {
    type      = "password"
    passwords = [random_password.valkey_password.result]
  }

  tags = {
    Name = "${var.prefix}-valkey-user"
  }
}

# ElastiCache User Group for Valkey serverless
# Required for serverless cache authentication
resource "aws_elasticache_user_group" "valkey" {
  user_group_id = "${var.prefix}-valkey-user-group"
  engine        = "valkey"
  user_ids      = [aws_elasticache_user.valkey.user_id]

  tags = {
    Name = "${var.prefix}-valkey-user-group"
  }
}

# CloudWatch log group for Valkey slow and engine logs
resource "aws_cloudwatch_log_group" "valkey_logs" {
  name              = "/aws/elasticache/${var.prefix}-valkey"
  retention_in_days = 180

  tags = {
    Name = "${var.prefix}-valkey-logs"
  }
}

# Subnet group for ElastiCache - uses same subnets as ECS tasks
resource "aws_elasticache_subnet_group" "valkey" {
  name       = "${var.prefix}-valkey-subnet-group"
  subnet_ids = local.ecs_subnets

  tags = {
    Name = "${var.prefix}-valkey-subnet-group"
  }
}

# Security group for Valkey
resource "aws_security_group" "valkey" {
  name        = "${var.prefix}-valkey"
  description = "Security group for ElastiCache Valkey used by n8n"
  vpc_id      = local.vpc_id

  # Allow inbound Valkey traffic from n8n ECS tasks
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.n8n.id]
    description     = "Valkey access from n8n ECS tasks"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.prefix}-valkey"
  }
}

# ElastiCache Serverless for Valkey
resource "aws_elasticache_serverless_cache" "valkey" {
  name        = "${var.prefix}-valkey"
  description = "Valkey serverless for n8n queue mode"

  # Engine configuration
  engine               = "valkey"
  major_engine_version = var.valkey_major_engine_version

  # Network configuration
  subnet_ids         = local.ecs_subnets
  security_group_ids = [aws_security_group.valkey.id]

  # User group access control (required for serverless)
  user_group_id = aws_elasticache_user_group.valkey.user_group_id

  # Serverless capacity configuration
  cache_usage_limits {
    data_storage {
      maximum = var.valkey_max_storage_gb
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = var.valkey_max_ecpu_per_second
    }
  }

  # Backup configuration
  daily_snapshot_time      = var.valkey_snapshot_time
  snapshot_retention_limit = var.valkey_snapshot_retention_limit

  tags = {
    Name = "${var.prefix}-valkey"
  }
}
