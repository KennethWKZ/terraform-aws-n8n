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
  prefix                = get_env("N8N_PREFIX", "n8n-new-vpc")
  certificate_arn       = get_env("N8N_CERTIFICATE_ARN", "")
  url                   = get_env("N8N_URL", "")
  desired_count         = get_env("N8N_DESIRED_COUNT", "1")
  container_image       = get_env("N8N_CONTAINER_IMAGE", "n8nio/n8n:latest")
  fargate_type          = get_env("N8N_FARGATE_TYPE", "FARGATE_SPOT")
  valkey_node_type       = get_env("N8N_VALKEY_NODE_TYPE", "cache.t4g.micro")
  valkey_num_cache_nodes = get_env("N8N_VALKEY_NUM_CACHE_NODES", "1")
  route53_zone_id       = get_env("N8N_ROUTE53_ZONE_ID", "")
  route53_record_name   = get_env("N8N_ROUTE53_RECORD_NAME", "")
  
  # Database configuration
  db_name                  = get_env("N8N_DB_NAME", "n8n")
  db_master_username       = get_env("N8N_DB_MASTER_USERNAME", "n8n_admin")
  db_engine_version        = get_env("N8N_DB_ENGINE_VERSION", "17.5")
  db_min_capacity          = get_env("N8N_DB_MIN_CAPACITY", "0.5")
  db_max_capacity          = get_env("N8N_DB_MAX_CAPACITY", "1")
  db_instance_count        = get_env("N8N_DB_INSTANCE_COUNT", "1")
  db_deletion_protection   = get_env("N8N_DB_DELETION_PROTECTION", "false")
  db_skip_final_snapshot   = get_env("N8N_DB_SKIP_FINAL_SNAPSHOT", "true")
}

# Provide inputs for the module
inputs = {
  # Prefix for all resources
  prefix = local.prefix

  # Optional: Customize other parameters via environment variables
  desired_count         = tonumber(local.desired_count)
  container_image       = local.container_image
  fargate_type          = local.fargate_type
  valkey_node_type       = local.valkey_node_type
  valkey_num_cache_nodes = tonumber(local.valkey_num_cache_nodes)
  
  # Optional: Route53 configuration for custom domain
  route53_zone_id     = local.route53_zone_id != "" ? local.route53_zone_id : null
  route53_record_name = local.route53_record_name != "" ? local.route53_record_name : null
  
  # Database configuration for Aurora Standard with Serverless v2
  db_name                = local.db_name
  db_master_username     = local.db_master_username
  db_engine_version      = local.db_engine_version
  db_min_capacity        = tonumber(local.db_min_capacity)
  db_max_capacity        = tonumber(local.db_max_capacity)
  db_instance_count      = tonumber(local.db_instance_count)
  db_deletion_protection = tobool(local.db_deletion_protection)
  db_skip_final_snapshot = tobool(local.db_skip_final_snapshot)

  # Note: When vpc_id is not specified, a new VPC will be created automatically
  # with public/private subnets, NAT Gateway, Internet Gateway, ElastiCache Redis, and Aurora Serverless v2
}
