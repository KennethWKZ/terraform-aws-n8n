# AWS Architecture Diagrams with Official AWS Icons

This directory contains AWS architecture diagrams generated using the **AWS Diagram MCP Server** for the N8n Queue Mode deployment.

## Overview

The diagrams are generated using the [AWS Diagram MCP Server](https://github.com/awslabs/aws-diagram-mcp-server), which provides official AWS architecture icons via the Model Context Protocol (MCP). This creates professional, publication-ready diagrams that are more visually appealing than text-based representations.

## Generated Diagrams

The script generates 7 comprehensive architecture diagrams:

1. **aws_n8n_architecture_overview.png** - High-level Queue Mode architecture showing N8n Main, Worker, and Browserless services with complete system flow, including Microsoft Entra ID SSO integration
2. **aws_n8n_architecture_comprehensive.png** - Detailed view of all components including EFS, S3, Cloud Map service discovery, serverless resources, and Microsoft Entra ID (SAML SSO)
3. **aws_n8n_network_architecture.png** - Detailed multi-AZ network architecture with VPC, subnets, routing, and service placement
4. **aws_n8n_security_architecture.png** - Security groups, IAM roles, access control patterns, and Microsoft Entra ID SAML 2.0 SSO flow
5. **aws_n8n_monitoring.png** - CloudWatch monitoring, SNS alerting, and observability configuration
6. **aws_n8n_queue_architecture.png** - Queue Mode workflow diagram showing job processing flow between Main service, Bull Queue, Worker services, and Browserless with Microsoft Entra ID authentication
7. **aws_n8n_dataflow.png** - Data flow diagram showing how data flows through the N8n Queue Mode system

## Microsoft Entra ID Integration

All diagrams now include **Microsoft Entra ID** (formerly Azure Active Directory) for Single Sign-On (SSO) authentication:

- **SAML 2.0 SSO**: Users authenticate via Microsoft Entra ID before accessing N8n
- **Just-in-Time Provisioning**: Users are automatically provisioned on first login
- **Role-based Access**: Instance roles can be provisioned from Entra ID claims
- **SSO Configuration**: Configurable via `N8N_SSO_*` environment variables

## Prerequisites

### MCP Server Setup

The diagrams are generated using the AWS Diagram MCP Server. To set it up, configure in your MCP client (e.g., Cline, Claude Desktop):

```json
{
  "mcpServers": {
    "awslabs.aws-diagram-mcp-server": {
      "command": "uvx",
      "args": ["awslabs.aws-diagram-mcp-server"]
    }
  }
}
```

The MCP server handles all dependencies internally - no local installation of graphviz or Python libraries required.

## Usage

### Generate Diagrams via MCP

Use the AWS Diagram MCP server tools:

1. **List available icons**:
```
use_mcp_tool: list_icons
  provider_filter: "aws"
```

2. **Get diagram examples**:
```
use_mcp_tool: get_diagram_examples
  diagram_type: "aws"
```

3. **Generate a diagram**:
```
use_mcp_tool: generate_diagram
  code: "with Diagram(...): ..."
  filename: "aws_n8n_architecture_overview"
  workspace_dir: "/path/to/project"
```

### Output

The MCP server generates PNG files in the `generated-diagrams/` directory:
- `aws_n8n_architecture_overview.png`
- `aws_n8n_architecture_comprehensive.png`
- `aws_n8n_network_architecture.png`
- `aws_n8n_security_architecture.png`
- `aws_n8n_monitoring.png`
- `aws_n8n_queue_architecture.png`
- `aws_n8n_dataflow.png`

Each diagram uses official AWS architecture icons and follows AWS diagramming best practices.

## Customization

To modify the diagrams via MCP, use the `generate_diagram` tool with custom code:

- **Change output format**: Modify the `filename` parameter (PNG output)
- **Adjust layout**: Change the `direction` parameter ("TB" for top-to-bottom, "LR" for left-to-right)
- **Add services**: Use icons from AWS, Azure, GCP, K8s, and other providers
- **Modify styling**: Update the `graph_attr` dictionary in the Diagram() call

## Architecture Details

The diagrams reflect the actual Terragrunt configuration from `stg/terragrunt/new-vpc/terragrunt.hcl` and `prod/terragrunt/new-vpc/terragrunt.hcl`:

### N8n Queue Mode Architecture

- **N8n Main Service**: Web UI, workflow management, job enqueuing (FARGATE_SPOT, desired count: 1)
- **N8n Worker Service**: Process queued jobs, execute workflows (FARGATE_SPOT, desired count: 2, configurable)
- **Task Runner Sidecar**: External task runner containers for workflow execution (n8n v2.0+)
- **Browserless Service**: Headless Chromium for web automation (WebSocket port 3000, FARGATE_SPOT)

### Infrastructure Components

- **Compute**: ECS Fargate with FARGATE_SPOT capacity provider
- **Containers**: n8nio/n8n:latest, n8nio/runners:latest, browserless/chrome:latest
- **Database**: Aurora Serverless v2 PostgreSQL 17.7 (0.5-4 ACU, AWS-managed Multi-AZ)
- **Cache & Queue**: ElastiCache Valkey Serverless (Bull Queue backend, AWS-managed Multi-AZ)
- **Storage**: EFS for shared files (/home/node/.n8n), S3 for binary data
- **Service Discovery**: AWS Cloud Map (browserless.local internal DNS)
- **Load Balancer**: Application Load Balancer with HTTPS/SSL termination (routes to Main service only)
- **DNS**: Route53 with ACM SSL certificate
- **Security**: AWS WAF Web ACL for edge protection
- **Identity**: Microsoft Entra ID for SAML 2.0 SSO authentication
- **Network**: VPC (10.0.0.0/16) with multi-AZ public/private subnets
- **Routing**: NAT Gateway and Internet Gateway

### Key Features

- **Microsoft Entra ID SSO**: SAML 2.0 Single Sign-On with Just-in-Time provisioning
- **Queue Mode**: Separate Main and Worker services for better scalability
- **Task Runner**: External task runners for isolated workflow execution (n8n v2.0+)
- **Multi-AZ High Availability**: AWS-managed for Aurora and Valkey Serverless
- **Service Discovery**: AWS Cloud Map for Browserless internal DNS resolution
- **Shared Storage**: EFS mounted to both Main and Worker services
- **Binary Data Storage**: S3 for large workflow artifacts
- **Encrypted Data**: At rest and in transit for all services
- **CloudWatch Monitoring**: Comprehensive logging and metrics (180 days retention)
- **Security**: Security groups and IAM role-based access control for each service
- **Secrets Management**: AWS Secrets Manager for credentials (DB, Valkey, Task Runner Token)

## Troubleshooting

### MCP Server Connection Issues

If the MCP server fails to connect:
1. Ensure `uvx` is installed: `pip install uvx`
2. Check the MCP client configuration
3. Verify the server is running: `uvx awslabs.aws-diagram-mcp-server`

### Custom Icons Not Supported

The MCP server runs in a sandboxed environment and cannot download custom icons. Use built-in provider icons:
- AWS icons: `Route53`, `ALB`, `Fargate`, `Aurora`, etc.
- Azure icons: Can use `Cognito` as stand-in for Microsoft Entra ID with clear labeling
- For true custom branding, use the Python `diagrams` library locally

## Additional Resources

- [AWS Diagram MCP Server](https://github.com/awslabs/aws-diagram-mcp-server)
- [Diagrams Library Documentation](https://diagrams.mingrammer.com/)
- [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/)
- [Mermaid Diagrams](aws-architecture-diagrams.md)
- [Microsoft Entra ID SAML SSO](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/configure-saml-single-sign-on)

## Queue Mode Benefits

The N8n Queue Mode architecture provides several advantages:

1. **Horizontal Scaling**: Worker services can scale independently from the Main service based on queue depth
2. **Resource Optimization**: Main service handles UI/API, workers handle compute-intensive jobs
3. **Better Reliability**: Job failures don't affect the web UI
4. **Cost Efficiency**: Scale workers only when needed, keep Main service minimal
5. **Performance**: Parallel job execution across multiple worker instances
6. **Task Isolation**: External task runners provide isolated execution environment

## Serverless Components

The architecture leverages AWS serverless services for cost optimization and high availability:

- **Aurora Serverless v2**: Auto-scales from 0.5 to 4 ACU, AWS-managed Multi-AZ failover
- **Valkey Serverless**: Auto-scales based on usage (5000 ECPU/s, 1GB storage), AWS-managed Multi-AZ replication
- **FARGATE_SPOT**: ~70% cost savings compared to on-demand Fargate

## Comparison with Mermaid Diagrams

This repository also contains `aws-architecture-diagrams.md` with text-based Mermaid diagrams. The Python-generated diagrams offer:

- ✅ Official AWS service icons
- ✅ Professional, publication-ready quality
- ✅ Better visual clarity for Queue Mode architecture
- ✅ Shows serverless resource representation accurately
- ✅ Easier to customize programmatically
- ✅ Microsoft Entra ID integration visualization

The Mermaid diagrams provide:

- ✅ More detailed component descriptions and data flows
- ✅ Sequence diagrams showing Queue Mode workflow execution
- ✅ Can be embedded in Markdown
- ✅ No installation dependencies
- ✅ Version control friendly (text-based)

Both approaches complement each other for different use cases.
