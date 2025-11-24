# Terragrunt configuration template for terraform-aws-n8n module
# This file uses environment variables for configuration
# See .env.example for required environment variables

locals {
  # Read environment variables with sensible defaults
  aws_region         = get_env("TG_AWS_REGION", "us-east-1")
  aws_profile        = get_env("TG_AWS_PROFILE", "")
  state_bucket       = get_env("TG_STATE_BUCKET", "")
  state_region       = get_env("TG_STATE_REGION", get_env("TG_AWS_REGION", "us-east-1"))
  use_lockfile       = get_env("TG_LOCKFILE", "1")
  
  # Default tags for all AWS resources
  default_tags = {
    env    = get_env("TG_TAG_ENV", "prod")
    region = get_env("TG_TAG_REGION", "global")
    team   = get_env("TG_TAG_TEAM", "engineering")
    app    = get_env("TG_TAG_APP", "n8n")
  }
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  
  config = {
    encrypt       = true
    bucket        = local.state_bucket
    key           = "${path_relative_to_include()}/terraform.tfstate"
    region        = local.state_region
    use_lockfile  = tobool(local.use_lockfile)
  }
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = var.aws_region
  %{if local.aws_profile != ""}profile = var.aws_profile%{endif}
}
EOF
}

# Define common variables that can be used across all modules
inputs = {
  aws_region  = local.aws_region
  aws_profile = local.aws_profile != "" ? local.aws_profile : null
  tags        = local.default_tags
}
