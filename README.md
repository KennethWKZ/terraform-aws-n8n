## Description

This sets up a N8n cluster in **Queue Mode** with separate Main and Worker services on ECS Fargate Spot, backed by Aurora Serverless v2 PostgreSQL and ElastiCache Valkey Serverless for queue management. The architecture includes:

- **N8n Main Service**: Handles web UI and API requests, enqueues workflow executions to the queue
- **N8n Worker Service**: Processes queued workflow executions in the background
- **Browserless Service**: Provides headless Chrome for browser automation workflows via WebSocket
- **Aurora Serverless v2**: PostgreSQL 17.5 database with 0.5-1 ACU auto-scaling for workflow data
- **ElastiCache Valkey Serverless**: Redis-compatible serverless cache as Bull Queue backend for job queue
- **EFS File System**: Shared storage for n8n data mounted to both Main and Worker services
- **S3 Bucket**: Binary data storage for large workflow artifacts
- **AWS Cloud Map**: Service discovery for internal DNS resolution (e.g., browserless.local)
- **Application Load Balancer**: SSL/TLS termination and traffic routing to Main service

The total costs are approximately $50-150 per month depending on usage patterns. SSL/TLS support via AWS Certificate Manager and Route53 is included for production deployments.

**Queue Mode Benefits**:
- Scalable workflow execution with dedicated worker processes
- Web UI remains responsive during heavy workflow processing
- Workers can scale independently based on queue depth
- Better resource isolation between UI and execution workloads

## Usage with Terragrunt

This module fully supports [Terragrunt](https://terragrunt.gruntwork.io/), a thin wrapper for Terraform that provides extra tools for keeping configurations DRY, managing remote state, and working with multiple modules.

### Prerequisites

**Recommended: Use tgenv for Terragrunt Version Management**

[tgenv](https://github.com/tgenv/tgenv) is a version manager for Terragrunt, similar to tfenv for Terraform. It allows you to easily install and switch between different Terragrunt versions, ensuring consistency across your team and CI/CD pipelines.

This repository includes a `.terragrunt-version` file that specifies the tested Terragrunt version (0.67.16). When you use tgenv, it automatically detects and uses this version.

**Installation:**

For macOS users with Homebrew:

```bash
brew install tgenv/tgenv/tgenv
```

For manual installation:

```bash
git clone https://github.com/tgenv/tgenv.git ~/.tgenv
echo 'export PATH="$HOME/.tgenv/bin:$PATH"' >> ~/.bashrc  # or ~/.zshrc
source ~/.bashrc  # or ~/.zshrc
```

**Usage:**

Once tgenv is installed, it automatically detects the `.terragrunt-version` file and installs/uses the specified version:

```bash
# Navigate to the repository
cd terraform-aws-n8n

# tgenv will automatically install and use version 0.67.16
tgenv install
tgenv use

# Or just run terragrunt commands directly - tgenv handles it automatically
terragrunt init
```

**Alternative: Direct Terragrunt Installation**

If you prefer not to use tgenv, you can install Terragrunt directly by following the [official installation guide](https://terragrunt.gruntwork.io/docs/getting-started/install/):

```bash
brew install terragrunt
```

### Configuration with Environment Variables

All Terragrunt configurations use environment variables for flexibility and security. This approach keeps sensitive values out of version control and makes it easy to switch between environments.

#### Step 1: Set Up Environment Variables

1. Copy the example environment file:

```bash
cp .env.example .env
```

2. Edit `.env` and configure your values:

```bash
# Required: Terragrunt remote state configuration
TG_AWS_REGION=us-east-1
TG_STATE_BUCKET=my-terraform-state-bucket
TG_STATE_REGION=us-east-1
TG_LOCKFILE=1

# Required: N8n configuration
N8N_PREFIX=n8n-demo
N8N_DESIRED_COUNT=1
N8N_CONTAINER_IMAGE=n8nio/n8n:latest
N8N_FARGATE_TYPE=FARGATE_SPOT

# For existing VPC deployments, also set:
N8N_VPC_ID=vpc-xxxxxxxxxxxxx
N8N_SUBNET_IDS=subnet-xxxxx,subnet-yyyyy
N8N_PUBLIC_SUBNET_IDS=subnet-xxxxx,subnet-yyyyy

# Optional: HTTPS support
N8N_CERTIFICATE_ARN=arn:aws:acm:region:account:certificate/xxxxx
N8N_URL=https://n8n.example.com/
```

3. Source the environment variables:

```bash
export $(cat .env | xargs)
```

**Important**: Add `.env` to your `.gitignore` to prevent committing sensitive values!

#### Step 2: Choose Your Deployment Scenario

The repository includes three Terragrunt example configurations in the `examples/terragrunt/` directory:

##### 1. New VPC (Automatic Creation)

Deploys N8n with an automatically created VPC. Only requires basic N8n configuration:

```bash
# Set environment variables
export $(cat .env | xargs)

# Deploy
cd examples/terragrunt/new-vpc
terragrunt init
terragrunt apply
```

**Required environment variables**:

- `TG_AWS_REGION`, `TG_STATE_BUCKET` (Terragrunt config)
- `N8N_PREFIX` (N8n config)

##### 2. Existing VPC with Public Subnets

Deploys N8n into an existing VPC using public subnets for ECS tasks:

```bash
# Set environment variables including VPC details
export $(cat .env | xargs)

# Deploy
cd examples/terragrunt/existing-vpc
terragrunt init
terragrunt apply
```

**Required environment variables**:

- `TG_AWS_REGION`, `TG_STATE_BUCKET` (Terragrunt config)
- `N8N_PREFIX`, `N8N_VPC_ID`, `N8N_SUBNET_IDS`, `N8N_PUBLIC_SUBNET_IDS`

**Optional**: `N8N_CERTIFICATE_ARN`, `N8N_URL` for HTTPS support

##### 3. Existing VPC with Private Subnets (Production Recommended)

Deploys N8n into an existing VPC using private subnets for ECS tasks (requires NAT Gateway for internet access):

```bash
# Set environment variables including VPC details
export $(cat .env | xargs)

# Deploy
cd examples/terragrunt/existing-vpc-private-subnets
terragrunt init
terragrunt apply
```

**Required environment variables**:

- `TG_AWS_REGION`, `TG_STATE_BUCKET` (Terragrunt config)
- `N8N_PREFIX`, `N8N_VPC_ID`, `N8N_SUBNET_IDS` (private subnets), `N8N_PUBLIC_SUBNET_IDS` (for ALB)

**Optional**: `N8N_CERTIFICATE_ARN`, `N8N_URL` for HTTPS support

### Environment Variables Reference

#### Terragrunt Configuration

- **TG_AWS_REGION**: AWS region for Terragrunt operations (default: `us-east-1`)
- **TG_AWS_PROFILE**: AWS profile to use for authentication (optional, useful for multi-account deployments)
- **TG_STATE_BUCKET**: S3 bucket name for Terraform state (required)
- **TG_STATE_REGION**: AWS region for state bucket (defaults to `TG_AWS_REGION`)
- **TG_LOCKFILE**: DynamoDB table for state locking (default: `1`)

#### N8n Configuration

##### Core Configuration
- **N8N_PREFIX**: Prefix for all AWS resources (default: varies by example)
- **N8N_DESIRED_COUNT**: Number of Main service ECS tasks (default: `1`, be careful with >1)
- **N8N_WORKER_DESIRED_COUNT**: Number of Worker service ECS tasks (default: `2`)
- **N8N_CONTAINER_IMAGE**: N8n Docker image (default: `n8nio/n8n:latest`)
- **N8N_FARGATE_TYPE**: `FARGATE` or `FARGATE_SPOT` (default: `FARGATE_SPOT`)

##### Network Configuration
- **N8N_VPC_ID**: VPC ID for deployment (required for existing VPC scenarios)
- **N8N_SUBNET_IDS**: Comma-separated subnet IDs for ECS tasks
- **N8N_PUBLIC_SUBNET_IDS**: Comma-separated public subnet IDs for ALB

##### SSL/HTTPS Configuration
- **N8N_CERTIFICATE_ARN**: ACM certificate ARN for HTTPS (optional)
- **N8N_URL**: Custom N8n URL with trailing slash (optional)

##### Queue Mode Configuration
- **N8N_WORKER_CPU**: Worker service CPU units (default: `1024`)
- **N8N_WORKER_MEMORY**: Worker service memory in MB (default: `2048`)
- **N8N_WORKER_CONCURRENCY**: Worker job concurrency (default: `20`)
- **N8N_MAIN_CONCURRENCY**: Main service concurrency (default: `15`)
- **N8N_MAIN_POOL_SIZE**: Main service database connection pool size (default: `10`)
- **N8N_WORKER_POOL_SIZE**: Worker service database connection pool size (default: `20`)

##### ElastiCache Valkey Serverless Configuration
- **N8N_VALKEY_SERVERLESS_ECPU**: Maximum ECPUs per second (default: `5000`)
- **N8N_VALKEY_SERVERLESS_STORAGE**: Maximum storage in GB (default: `1`)
- **N8N_VALKEY_SERVERLESS_ENGINE_VERSION**: Valkey major engine version (default: `8`)

##### Database Configuration (Aurora Serverless v2)
- **N8N_DB_NAME**: Database name (default: `n8n`)
- **N8N_DB_MASTER_USERNAME**: Database master username (default: `n8n_admin`)
- **N8N_DB_ENGINE_VERSION**: PostgreSQL engine version (default: `17.5`)
- **N8N_DB_MIN_CAPACITY**: Minimum ACUs (default: `0.5`)
- **N8N_DB_MAX_CAPACITY**: Maximum ACUs (default: `4`)
- **N8N_DB_INSTANCE_COUNT**: Number of database instances (default: `1`)
- **N8N_DB_DELETION_PROTECTION**: Enable deletion protection (default: `false`)
- **N8N_DB_SKIP_FINAL_SNAPSHOT**: Skip final snapshot on deletion (default: `true`)

##### Security Configuration
- **N8N_WAF_ARN**: AWS WAF Web ACL ARN for ALB protection (optional)

##### Browserless Configuration
- **N8N_BROWSERLESS_ENABLED**: Enable Browserless service (default: `0`, set to `1` to enable)
- **N8N_BROWSERLESS_TOKEN**: Browserless authentication token (required if enabled)

##### SMTP Configuration
- **N8N_SMTP_HOST**: SMTP server host (optional)
- **N8N_SMTP_PORT**: SMTP server port (default: `465`)
- **N8N_SMTP_USER**: SMTP username (optional)
- **N8N_SMTP_PASS**: SMTP password (optional)
- **N8N_SMTP_SENDER**: SMTP sender email address (optional)
- **N8N_SMTP_SSL**: Enable SSL for SMTP (default: `true`)

#### Route53 Configuration (Optional)

- **N8N_ROUTE53_ZONE_ID**: Route53 hosted zone ID for automatic DNS record creation (optional, e.g., `Z1234567890ABC`)
- **N8N_ROUTE53_RECORD_NAME**: Route53 record name/subdomain (optional, e.g., `n8n` for `n8n.example.com`)

When both `N8N_ROUTE53_ZONE_ID` and `N8N_ROUTE53_RECORD_NAME` are provided, Terragrunt will automatically create a Route53 A record pointing to the ALB. This eliminates the need to manually configure DNS after deployment.

**Example usage:**

```bash
# In your .env file
N8N_ROUTE53_ZONE_ID=Z1234567890ABC
N8N_ROUTE53_RECORD_NAME=n8n

# This will create: n8n.example.com -> ALB DNS name (alias record)
```

### Common Terragrunt Commands

```bash
# Initialize Terragrunt (downloads module and initializes Terraform)
terragrunt init

# Plan changes
terragrunt plan

# Apply configuration
terragrunt apply

# Destroy infrastructure
terragrunt destroy

# Show outputs
terragrunt output

# Validate configuration
terragrunt validate
```

### Managing Multiple Environments

Use different `.env` files for different environments:

```bash
# Development environment
cp .env.example .env.dev
# Edit .env.dev with dev values
export $(cat .env.dev | xargs)
cd examples/terragrunt/new-vpc
terragrunt apply

# Production environment
cp .env.example .env.prod
# Edit .env.prod with prod values
export $(cat .env.prod | xargs)
cd examples/terragrunt/existing-vpc-private-subnets
terragrunt apply
```

### ElastiCache Valkey Serverless and NAT Gateway Support

All Terragrunt examples include full support for:

#### ElastiCache Valkey Serverless (Queue Mode)

- **Automatically deployed** as a fully managed serverless cache for N8n queue management
- Serverless architecture with automatic scaling based on workload
- Security group automatically configured to allow Valkey traffic from N8n ECS tasks
- Configurable via environment variables:
  - `N8N_VALKEY_SERVERLESS_ECPU`: Maximum ECPUs per second (default: `5000`)
  - `N8N_VALKEY_SERVERLESS_STORAGE`: Maximum storage in GB (default: `1`)
  - `N8N_VALKEY_SERVERLESS_ENGINE_VERSION`: Valkey major version (default: `8`)
- Valkey endpoint automatically injected into N8n container environment
- No node provisioning or management required - fully AWS-managed

#### NAT Gateway

- **New VPC deployments**: NAT Gateway is automatically created via the terraform-aws-modules/vpc module
  - Enables ECS tasks in private subnets to access the internet (Docker Hub, external APIs, etc.)
  - One NAT Gateway per availability zone for high availability
- **Existing VPC with private subnets**: You must ensure your VPC has a NAT Gateway configured
  - Private subnets require NAT Gateway for outbound internet access
  - Without NAT Gateway, ECS tasks cannot pull Docker images or access external services
  - Alternatively, you can use VPC endpoints for AWS services

### Benefits of Using Terragrunt

- **DRY Configurations**: Define common settings once in the root `terragrunt.hcl`
- **Remote State Management**: Automatic S3 backend configuration with locking
- **Provider Generation**: No need to define AWS provider in each configuration
- **Environment Variables**: Keep sensitive values secure and out of version control
- **Multiple Environments**: Easily manage dev, staging, and production with different `.env` files
- **Dependency Management**: Handle dependencies between multiple Terraform modules
- **CLI Wrapper**: All standard Terraform commands work through Terragrunt

## Requirements

No requirements.

## Providers

| Name                                             | Version |
| ------------------------------------------------ | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws) | n/a     |

## Modules

| Name                                         | Source                        | Version |
| -------------------------------------------- | ----------------------------- | ------- |
| <a name="module_vpc"></a> [vpc](#module_vpc) | terraform-aws-modules/vpc/aws | n/a     |

## Resources

| Name                                                                                                                                                  | Type        |
| ----------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [aws_cloudwatch_log_group.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)                     | resource    |
| [aws_ecs_cluster.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster)                                        | resource    |
| [aws_ecs_cluster_capacity_providers.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource    |
| [aws_ecs_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)                                    | resource    |
| [aws_ecs_task_definition.taskdef](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition)                    | resource    |
| [aws_efs_access_point.access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_access_point)                           | resource    |
| [aws_efs_file_system.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system)                               | resource    |
| [aws_efs_mount_target.mount](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target)                            | resource    |
| [aws_iam_role.executionrole](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                    | resource    |
| [aws_iam_role.taskrole](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                         | resource    |
| [aws_lb.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)                                                         | resource    |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener)                                       | resource    |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener)                                      | resource    |
| [aws_lb_target_group.ip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group)                                 | resource    |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                  | resource    |
| [aws_security_group.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                  | resource    |
| [aws_security_group.n8n](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                  | resource    |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones)                 | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)                         | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)                                           | data source |

## Inputs

| Name                                                                                                   | Description                                                                                                                           | Type           | Default                               | Required |
| ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------- | :------: |
| <a name="input_alb_allowed_cidr_blocks"></a> [alb_allowed_cidr_blocks](#input_alb_allowed_cidr_blocks) | List of CIDR blocks allowed to access the ALB (default: allows all traffic)                                                           | `list(string)` | `["0.0.0.0/0"]`                       |    no    |
| <a name="input_certificate_arn"></a> [certificate_arn](#input_certificate_arn)                         | Certificate ARN for HTTPS support                                                                                                     | `string`       | `null`                                |    no    |
| <a name="input_container_image"></a> [container_image](#input_container_image)                         | Container image to use for n8n                                                                                                        | `string`       | `"n8nio/n8n:1.4.0"`                   |    no    |
| <a name="input_desired_count"></a> [desired_count](#input_desired_count)                               | Desired count of n8n tasks, be careful with this to make it more than 1 as it can cause issues with webhooks not registering properly | `number`       | `1`                                   |    no    |
| <a name="input_fargate_type"></a> [fargate_type](#input_fargate_type)                                  | Fargate type to use for n8n (either FARGATE or FARGATE_SPOT))                                                                         | `string`       | `"FARGATE_SPOT"`                      |    no    |
| <a name="input_prefix"></a> [prefix](#input_prefix)                                                    | Prefix to add to all resources                                                                                                        | `string`       | `"n8n"`                               |    no    |
| <a name="input_public_subnet_ids"></a> [public_subnet_ids](#input_public_subnet_ids)                   | Public subnet IDs for ALB (optional, uses VPC public subnets if not provided)                                                         | `list(string)` | `[]`                                  |    no    |
| <a name="input_ssl_policy"></a> [ssl_policy](#input_ssl_policy)                                        | SSL policy for HTTPS listner.                                                                                                         | `string`       | `ELBSecurityPolicy-TLS13-1-2-2021-06` |    no    |
| <a name="input_subnet_ids"></a> [subnet_ids](#input_subnet_ids)                                        | Subnet IDs for ECS tasks (optional, uses VPC subnets if not provided)                                                                 | `list(string)` | `[]`                                  |    no    |
| <a name="input_tags"></a> [tags](#input_tags)                                                          | Tags to apply to all resources                                                                                                        | `map(string)`  | `null`                                |    no    |
| <a name="input_url"></a> [url](#input_url)                                                             | URL for n8n (default is LB url), needs a trailing slash if you specify it                                                             | `string`       | `null`                                |    no    |
| <a name="input_use_private_subnets"></a> [use_private_subnets](#input_use_private_subnets)             | Whether to deploy ECS tasks in private subnets (requires NAT Gateway or VPC endpoints for internet access)                            | `bool`         | `false`                               |    no    |
| <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id)                                                    | VPC ID to deploy n8n into (optional, creates new VPC if not provided)                                                                 | `string`       | `null`                                |    no    |

## Outputs

| Name                                                                 | Description            |
| -------------------------------------------------------------------- | ---------------------- |
| <a name="output_lb_dns_name"></a> [lb_dns_name](#output_lb_dns_name) | Load balancer DNS name |
