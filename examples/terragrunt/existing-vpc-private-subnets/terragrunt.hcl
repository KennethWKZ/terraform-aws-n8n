# Terragrunt configuration for deploying N8n in an existing VPC with private subnets
# This example shows how to deploy N8n with ECS tasks in private subnets (recommended for production)
# The ALB will be in public subnets while ECS tasks run in private subnets with NAT Gateway access

# Include the root terragrunt.hcl configuration
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Reference the parent module
terraform {
  source = "../../.."
}

# Define local variables from environment variables
locals {
  prefix            = get_env("N8N_PREFIX", "n8n-private")
  vpc_id            = get_env("N8N_VPC_ID", "")
  subnet_ids        = split(",", get_env("N8N_SUBNET_IDS", ""))
  public_subnet_ids = split(",", get_env("N8N_PUBLIC_SUBNET_IDS", ""))
  certificate_arn   = get_env("N8N_CERTIFICATE_ARN", "")
  url               = get_env("N8N_URL", "")
  desired_count     = get_env("N8N_DESIRED_COUNT", "1")
  container_image       = get_env("N8N_CONTAINER_IMAGE", "n8nio/n8n:latest")
  fargate_type          = get_env("N8N_FARGATE_TYPE", "FARGATE_SPOT")
  valkey_node_type       = get_env("N8N_VALKEY_NODE_TYPE", "cache.t4g.micro")
  valkey_num_cache_nodes = get_env("N8N_VALKEY_NUM_CACHE_NODES", "1")
  route53_zone_id       = get_env("N8N_ROUTE53_ZONE_ID", "")
  route53_record_name   = get_env("N8N_ROUTE53_RECORD_NAME", "")
  
  # Aurora Standard with Serverless v2 configuration
  db_name                  = get_env("N8N_DB_NAME", "n8n")
  db_master_username       = get_env("N8N_DB_MASTER_USERNAME", "n8n_admin")
  db_engine_version        = get_env("N8N_DB_ENGINE_VERSION", "17.7")
  db_min_capacity          = get_env("N8N_DB_MIN_CAPACITY", "0.5")
  db_max_capacity          = get_env("N8N_DB_MAX_CAPACITY", "1")
  db_deletion_protection   = get_env("N8N_DB_DELETION_PROTECTION", "false")
  db_skip_final_snapshot   = get_env("N8N_DB_SKIP_FINAL_SNAPSHOT", "true")
}

# Module inputs
inputs = merge(
  {
    prefix              = local.prefix
    vpc_id              = local.vpc_id
    use_private_subnets = true
    subnet_ids          = local.subnet_ids
    public_subnet_ids   = local.public_subnet_ids
    desired_count       = tonumber(local.desired_count)
    container_image       = local.container_image
    fargate_type          = local.fargate_type
    valkey_node_type       = local.valkey_node_type
    valkey_num_cache_nodes = tonumber(local.valkey_num_cache_nodes)
  },
  local.certificate_arn != "" ? { certificate_arn = local.certificate_arn } : {},
  local.url != "" ? { url = local.url } : {},
  local.route53_zone_id != "" ? { route53_zone_id = local.route53_zone_id } : {},
  local.route53_record_name != "" ? { route53_record_name = local.route53_record_name } : {},
  {
    db_name                = local.db_name
    db_master_username     = local.db_master_username
    db_engine_version      = local.db_engine_version
    db_min_capacity        = tonumber(local.db_min_capacity)
    db_max_capacity        = tonumber(local.db_max_capacity)
    db_deletion_protection = tobool(local.db_deletion_protection)
    db_skip_final_snapshot = tobool(local.db_skip_final_snapshot)
  }
)
