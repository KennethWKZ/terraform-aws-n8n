# Random password for Aurora database
resource "random_password" "db_password" {
  length  = 32
  special = true
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# AWS Secrets Manager secret for database credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name_prefix             = "${var.prefix}-db-credentials-"
  description             = "Database credentials for n8n"
  recovery_window_in_days = var.db_secret_recovery_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_rds_cluster.aurora.endpoint
    port     = aws_rds_cluster.aurora.port
    dbname   = var.db_name
  })
}

# Security group for Aurora
resource "aws_security_group" "aurora" {
  name_prefix = "${var.prefix}-aurora-sg-"
  description = "Security group for Aurora Standard cluster"
  vpc_id      = local.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.n8n.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.prefix}-aurora-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "aurora" {
  name_prefix = "${var.prefix}-aurora-subnet-group-"
  description = "Subnet group for Aurora Standard"
  subnet_ids  = try(length(var.db_subnet_ids), 0) > 0 ? var.db_subnet_ids : local.ecs_subnets

  tags = merge(
    var.tags,
    {
      Name = "${var.prefix}-aurora-subnet-group"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "aurora" {
  name_prefix = "${var.prefix}-aurora-cluster-pg-"
  family      = var.db_parameter_group_family
  description = "Cluster parameter group for Aurora Standard"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# RDS DB Parameter Group
resource "aws_db_parameter_group" "aurora" {
  name_prefix = "${var.prefix}-aurora-db-pg-"
  family      = var.db_parameter_group_family
  description = "DB parameter group for Aurora Standard"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Aurora Standard Cluster with Serverless v2
resource "aws_rds_cluster" "aurora" {
  cluster_identifier              = "${var.prefix}-aurora-cluster"
  engine                          = "aurora-postgresql"
  engine_mode                     = "provisioned"
  engine_version                  = var.db_engine_version
  database_name                   = var.db_name
  master_username                 = var.db_master_username
  master_password                 = random_password.db_password.result
  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]

  # Enable RDS Data API for HTTP-based database access
  enable_http_endpoint = var.db_enable_http_endpoint

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    min_capacity = var.db_min_capacity
    max_capacity = var.db_max_capacity
  }

  # Backup configuration
  backup_retention_period      = var.db_backup_retention_period
  preferred_backup_window      = var.db_backup_window
  preferred_maintenance_window = var.db_maintenance_window

  # Enable encryption
  storage_encrypted = true
  kms_key_id        = var.db_kms_key_id

  # Skip final snapshot for easier cleanup (change to false in production)
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${var.prefix}-aurora-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Enable deletion protection (recommended for production)
  deletion_protection = var.db_deletion_protection

  # Copy tags to snapshots
  copy_tags_to_snapshot = true

  # Enable CloudWatch logs export
  # enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = var.tags
}

# Aurora Serverless v2 Instance
resource "aws_rds_cluster_instance" "aurora" {
  count                        = var.db_instance_count
  identifier                   = "${var.prefix}-aurora-instance-${count.index + 1}"
  cluster_identifier           = aws_rds_cluster.aurora.id
  instance_class               = "db.serverless"
  engine                       = aws_rds_cluster.aurora.engine
  engine_version               = aws_rds_cluster.aurora.engine_version
  db_parameter_group_name      = aws_db_parameter_group.aurora.name
  publicly_accessible          = false
  auto_minor_version_upgrade   = var.db_auto_minor_version_upgrade
  performance_insights_enabled = var.db_performance_insights_enabled

  tags = merge(
    var.tags,
    {
      Name = "${var.prefix}-aurora-instance-${count.index + 1}"
    }
  )
}
