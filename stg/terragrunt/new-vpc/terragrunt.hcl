# Terragrunt configuration for deploying N8n with a new VPC
# This example creates a new VPC with all required networking components
# Configuration values are read from environment variables

# Include the root terragrunt configuration
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Reference the parent Terraform module
terraform {
  source = "../../.."
}

locals {
  # Read environment variables with defaults
  prefix                          = get_env("N8N_PREFIX", "n8n-new-vpc")
  certificate_arn                 = get_env("N8N_CERTIFICATE_ARN", "")
  url                             = get_env("N8N_URL", "")
  desired_count                   = get_env("N8N_DESIRED_COUNT", "1")
  worker_desired_count            = get_env("N8N_WORKER_DESIRED_COUNT", "2")
  worker_cpu                      = get_env("N8N_WORKER_CPU", "1024")
  worker_memory                   = get_env("N8N_WORKER_MEMORY", "2048")
  worker_concurrency              = get_env("N8N_WORKER_CONCURRENCY", "20")
  main_concurrency                = get_env("N8N_MAIN_CONCURRENCY", "15")
  main_pool_size                  = get_env("N8N_MAIN_POOL_SIZE", "10")
  worker_pool_size                = get_env("N8N_WORKER_POOL_SIZE", "20")
  container_image                 = get_env("N8N_CONTAINER_IMAGE", "n8nio/n8n:latest")
  fargate_type                    = get_env("N8N_FARGATE_TYPE", "FARGATE_SPOT")
  valkey_max_ecpu_per_second      = get_env("N8N_VALKEY_SERVERLESS_ECPU", "5000")
  valkey_max_storage_gb           = get_env("N8N_VALKEY_SERVERLESS_STORAGE", "1")
  valkey_major_engine_version     = get_env("N8N_VALKEY_SERVERLESS_ENGINE_VERSION", "8")
  route53_zone_id                 = get_env("N8N_ROUTE53_ZONE_ID", "")
  route53_record_name             = get_env("N8N_ROUTE53_RECORD_NAME", "")
  
  # Database configuration
  db_name                  = get_env("N8N_DB_NAME", "n8n")
  db_master_username       = get_env("N8N_DB_MASTER_USERNAME", "n8n_admin")
  db_engine_version        = get_env("N8N_DB_ENGINE_VERSION", "17.5")
  db_min_capacity          = get_env("N8N_DB_MIN_CAPACITY", "0.5")
  db_max_capacity          = get_env("N8N_DB_MAX_CAPACITY", "4")
  db_instance_count        = get_env("N8N_DB_INSTANCE_COUNT", "1")
  db_deletion_protection   = get_env("N8N_DB_DELETION_PROTECTION", "false")
  db_skip_final_snapshot   = get_env("N8N_DB_SKIP_FINAL_SNAPSHOT", "true")

  waf_web_acl_arn = get_env("N8N_WAF_ARN", "")

  browserless_enabled = get_env("N8N_BROWSERLESS_ENABLED", "0")
  browserless_token = get_env("N8N_BROWSERLESS_TOKEN", "")
  
  # SMTP configuration for email functionality
  smtp_host   = get_env("N8N_SMTP_HOST", "")
  smtp_port   = get_env("N8N_SMTP_PORT", "465")
  smtp_user   = get_env("N8N_SMTP_USER", "")
  smtp_pass   = get_env("N8N_SMTP_PASS", "")
  smtp_sender = get_env("N8N_SMTP_SENDER", "")
  smtp_ssl    = get_env("N8N_SMTP_SSL", "true")
}

# Provide inputs for the module
inputs = {
  # Prefix for all resources
  prefix = local.prefix

  # Optional: Customize other parameters via environment variables
  desired_count               = tonumber(local.desired_count)
  worker_desired_count        = tonumber(local.worker_desired_count)
  worker_cpu                  = tonumber(local.worker_cpu)
  worker_memory               = tonumber(local.worker_memory)
  worker_concurrency          = tonumber(local.worker_concurrency)
  main_concurrency            = tonumber(local.main_concurrency)
  main_pool_size              = tonumber(local.main_pool_size)
  worker_pool_size            = tonumber(local.worker_pool_size)
  container_image             = local.container_image
  fargate_type                = local.fargate_type
  valkey_max_ecpu_per_second  = tonumber(local.valkey_max_ecpu_per_second)
  valkey_max_storage_gb       = tonumber(local.valkey_max_storage_gb)
  valkey_major_engine_version = tonumber(local.valkey_major_engine_version)
  
  # Optional: SSL/HTTPS configuration
  certificate_arn = local.certificate_arn != "" ? local.certificate_arn : null
  url             = local.url != "" ? local.url : null
  
  # Optional: Route53 configuration for custom domain
  route53_zone_id     = local.route53_zone_id != "" ? local.route53_zone_id : null
  route53_record_name = local.route53_record_name != "" ? local.route53_record_name : null
  
  # Database configuration for Aurora Serverless v2
  db_name                = local.db_name
  db_master_username     = local.db_master_username
  db_engine_version      = local.db_engine_version
  db_min_capacity        = tonumber(local.db_min_capacity)
  db_max_capacity        = tonumber(local.db_max_capacity)
  db_instance_count      = tonumber(local.db_instance_count)
  db_deletion_protection = tobool(local.db_deletion_protection)
  db_skip_final_snapshot = tobool(local.db_skip_final_snapshot)

  waf_web_acl_arn = local.waf_web_acl_arn != "" ? local.waf_web_acl_arn : null

  browserless_enabled = tobool(local.browserless_enabled)
  browserless_token = local.browserless_token 

  # SMTP configuration for email functionality
  smtp_host   = local.smtp_host != "" ? local.smtp_host : null
  smtp_port   = tonumber(local.smtp_port)
  smtp_user   = local.smtp_user != "" ? local.smtp_user : null
  smtp_pass   = local.smtp_pass != "" ? local.smtp_pass : null
  smtp_sender = local.smtp_sender != "" ? local.smtp_sender : null
  smtp_ssl    = tobool(local.smtp_ssl)

  n8n_force_new_deployment          = true
  browserless_force_new_deployment  = true

  # Note: When vpc_id is not specified, a new VPC will be created automatically
  # with public/private subnets, NAT Gateway, Internet Gateway, ElastiCache Redis, and Aurora Serverless v2
}
