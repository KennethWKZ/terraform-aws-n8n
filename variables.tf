variable "aws_region" {
  type        = string
  description = "AWS region for resource deployment"
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS profile to use for authentication (optional)"
  default     = null
}

variable "prefix" {
  type        = string
  description = "Prefix to add to all resources"
  default     = "n8n"
}

variable "certificate_arn" {
  type        = string
  description = "Certificate ARN for HTTPS support"
  default     = null
}

variable "url" {
  type        = string
  description = "URL for n8n (default is LB url), needs a trailing slash if you specify it"
  default     = null
}

variable "desired_count" {
  type        = number
  description = "Desired count of n8n main instances (handles webhooks and triggers)"
  default     = 2
}

variable "worker_desired_count" {
  type        = number
  description = "Desired count of n8n worker instances (processes queued executions)"
  default     = 2
}

variable "worker_cpu" {
  type        = number
  description = "CPU units for n8n worker tasks (1024 = 1 vCPU)"
  default     = 1024
}

variable "worker_memory" {
  type        = number
  description = "Memory in MB for n8n worker tasks"
  default     = 2048
}

variable "worker_concurrency" {
  type        = number
  description = "Maximum concurrent executions per worker instance"
  default     = 20
}

variable "main_concurrency" {
  type        = number
  description = "Maximum concurrent executions per main instance"
  default     = 15
}

variable "main_pool_size" {
  type        = number
  description = "Database connection pool size for main instances"
  default     = 10
}

variable "worker_pool_size" {
  type        = number
  description = "Database connection pool size for worker instances"
  default     = 20
}

variable "container_image" {
  type        = string
  description = "Container image to use for n8n"
  default     = "n8nio/n8n:latest"
}

variable "fargate_type" {
  type        = string
  description = "Fargate type to use for n8n (either FARGATE or FARGATE_SPOT))"
  default     = "FARGATE"
}

variable "ssl_policy" {
  type        = string
  description = "The name of the SSL policy to use for the HTTPS Listener on the ALB"
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = null
}

variable "waf_web_acl_arn" {
  description = "ARN of the existing WAF WebACL to associate with the ALB"
  type        = string
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy n8n into (optional, creates new VPC if not provided)"
  default     = null
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for ECS tasks (optional, uses VPC subnets if not provided)"
  default     = []
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for ALB (optional, uses VPC public subnets if not provided)"
  default     = []
}

variable "use_private_subnets" {
  type        = bool
  description = "Whether to deploy ECS tasks in private subnets (requires NAT Gateway or VPC endpoints for internet access)"
  default     = true
}

variable "alb_allowed_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks allowed to access the ALB (default: allows all traffic)"
  default     = ["0.0.0.0/0"]
}

variable "valkey_major_engine_version" {
  type        = string
  description = "ElastiCache Valkey major engine version for serverless"
  default     = "8"
}

variable "valkey_max_storage_gb" {
  type        = number
  description = "Maximum data storage in GB for ElastiCache Valkey serverless"
  default     = 10
}

variable "valkey_max_ecpu_per_second" {
  type        = number
  description = "Maximum ECPUs per second for ElastiCache Valkey serverless"
  default     = 5000
}

variable "valkey_snapshot_time" {
  type        = string
  description = "Daily snapshot time for ElastiCache Valkey serverless (HH:MM format in UTC)"
  default     = "16:00"
}

variable "valkey_snapshot_retention_limit" {
  type        = number
  description = "Number of days to retain snapshots for ElastiCache Valkey serverless (1-35)"
  default     = 7
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 hosted zone ID for creating DNS record (optional)"
  default     = null
}

variable "route53_record_name" {
  type        = string
  description = "Route53 record name (e.g., 'n8n' for n8n.example.com) (optional)"
  default     = null
}

# Aurora Serverless v2 Database Variables
variable "db_name" {
  type        = string
  description = "Name of the PostgreSQL database to create"
  default     = "n8n"
}

variable "db_master_username" {
  type        = string
  description = "Master username for Aurora database"
  default     = "n8n_admin"
}

variable "db_engine_version" {
  type        = string
  description = "Aurora PostgreSQL engine version"
  default     = "17.5"
}

variable "db_parameter_group_family" {
  type        = string
  description = "Aurora PostgreSQL parameter group family"
  default     = "aurora-postgresql17"
}

variable "db_min_capacity" {
  type        = number
  description = "Minimum capacity for Aurora Serverless v2 (ACU)"
  default     = 0.5
}

variable "db_max_capacity" {
  type        = number
  description = "Maximum capacity for Aurora Serverless v2 (ACU)"
  default     = 1
}

variable "db_instance_count" {
  type        = number
  description = "Number of Aurora Serverless v2 instances to create (1 for single instance, 2+ for high availability)"
  default     = 1
}

variable "db_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for Aurora database (optional, uses ECS subnets if not provided)"
  default     = null
}

variable "db_backup_retention_period" {
  type        = number
  description = "Number of days to retain automated backups (1-35)"
  default     = 7
}

variable "db_backup_window" {
  type        = string
  description = "Preferred backup window (UTC time)"
  default     = "16:00-17:00"
}

variable "db_maintenance_window" {
  type        = string
  description = "Preferred maintenance window"
  default     = "thu:18:00-thu:19:00"
}

variable "db_kms_key_id" {
  type        = string
  description = "KMS key ID for database encryption (optional, uses default AWS RDS key if not provided)"
  default     = null
}

variable "db_skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot when destroying the cluster (set to false in production)"
  default     = true
}

variable "db_deletion_protection" {
  type        = bool
  description = "Enable deletion protection for the Aurora cluster"
  default     = false
}

variable "db_auto_minor_version_upgrade" {
  type        = bool
  description = "Enable automatic minor version upgrades"
  default     = true
}

variable "db_performance_insights_enabled" {
  type        = bool
  description = "Enable Performance Insights for Aurora instances"
  default     = false
}

variable "db_secret_recovery_days" {
  type        = number
  description = "Number of days to retain deleted secrets (0 for immediate deletion, 7-30 for recovery window)"
  default     = 7
}

variable "db_enable_http_endpoint" {
  type        = bool
  description = "Enable RDS Data API for HTTP-based database access without managing connections"
  default     = true
}

# Browserless Configuration Variables
variable "browserless_enabled" {
  type        = bool
  description = "Enable browserless service for browser automation"
  default     = false
}

variable "browserless_container_image" {
  type        = string
  description = "Container image for browserless service"
  default     = "ghcr.io/browserless/chromium:latest"
}

variable "browserless_token" {
  type        = string
  description = "Authentication token for browserless service"
  default     = "testtoken"
  sensitive   = true
}

variable "browserless_cpu" {
  type        = number
  description = "CPU units for browserless task (1024 = 1 vCPU)"
  default     = 1024
}

variable "browserless_memory" {
  type        = number
  description = "Memory in MB for browserless task"
  default     = 2048
}

variable "browserless_desired_count" {
  type        = number
  description = "Desired count of browserless tasks"
  default     = 1
}

variable "browserless_max_concurrent_sessions" {
  type        = number
  description = "Maximum concurrent browser sessions"
  default     = 10
}

variable "browserless_timeout" {
  type        = number
  description = "Timeout in milliseconds for browser sessions"
  default     = 300000
}

# SMTP Configuration Variables for Email Functionality
variable "smtp_host" {
  type        = string
  description = "SMTP server host for email delivery"
  default     = null
}

variable "smtp_port" {
  type        = number
  description = "SMTP server port"
  default     = 465
}

variable "smtp_user" {
  type        = string
  description = "SMTP authentication username"
  default     = null
  sensitive   = true
}

variable "smtp_pass" {
  type        = string
  description = "SMTP authentication password"
  default     = null
  sensitive   = true
}

variable "smtp_sender" {
  type        = string
  description = "Email address to use as sender"
  default     = null
}

variable "smtp_ssl" {
  type        = bool
  description = "Enable SSL/TLS for SMTP connection"
  default     = true
}

# ECS Deployment Configuration
variable "n8n_force_new_deployment" {
  type        = bool
  description = "Force a new deployment of the ECS service to pull latest n8n container image. Set to true to trigger redeployment, then set back to false."
  default     = false
}

variable "browserless_force_new_deployment" {
  type        = bool
  description = "Force a new deployment of the ECS service to pull latest n8n - browserless container image. Set to true to trigger redeployment, then set back to false."
  default     = false
}

# Task Runner Configuration Variables (n8n v2.0+)
variable "task_runner_enabled" {
  type        = bool
  description = "Enable task runners for Code node execution (required for n8n v2.0+)"
  default     = true
}

variable "task_runner_mode" {
  type        = string
  description = "Task runner mode: 'internal' (child process) or 'external' (sidecar container). External mode is recommended for production."
  default     = "external"
  validation {
    condition     = contains(["internal", "external"], var.task_runner_mode)
    error_message = "Task runner mode must be either 'internal' or 'external'."
  }
}

variable "task_runner_image" {
  type        = string
  description = "Container image for task runners (n8n v2.0+ external mode)"
  default     = "n8nio/runners:latest"
}

variable "task_runner_cpu" {
  type        = number
  description = "CPU units for task runner sidecar container (1024 = 1 vCPU). Task runners execute Code node JavaScript/Python. Must result in valid Fargate total when added to worker_cpu (valid totals: 1024, 2048, 4096)."
  default     = 1024
}

variable "task_runner_memory" {
  type        = number
  description = "Memory in MB for task runner sidecar container. Must result in valid Fargate total when added to worker_memory. For 2048 CPU, valid memory range is 4096-16384 MB."
  default     = 2048
}

variable "task_runner_auto_shutdown_timeout" {
  type        = number
  description = "Auto shutdown timeout in seconds for idle task runners (0 to disable)"
  default     = 15
}

variable "offload_manual_executions_to_workers" {
  type        = bool
  description = "Offload manual executions to workers. When true, main instances don't need task runner sidecars."
  default     = true
}

# Daily ECS Redeployment (EventBridge Scheduler)
variable "daily_redeployment_enabled" {
  type        = bool
  description = "Enable daily EventBridge Scheduler-driven ECS redeployment (calls ecs:UpdateService with forceNewDeployment=true)"
  default     = true
}

variable "daily_redeployment_cron" {
  type        = string
  description = "Cron expression for daily ECS redeployment in EventBridge Scheduler format. Default: 01:00 daily."
  default     = "cron(0 1 * * ? *)"
}

variable "daily_redeployment_timezone" {
  type        = string
  description = "IANA timezone for the daily redeployment schedule (e.g. Asia/Kuala_Lumpur, UTC)"
  default     = "Asia/Kuala_Lumpur"
}

# Additional Environment Variables
variable "additional_n8n_env_vars" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "Additional environment variables to pass to n8n containers"
  default     = []
}
