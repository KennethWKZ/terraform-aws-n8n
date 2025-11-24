# AWS Architecture Diagrams with Official AWS Icons

This directory contains Python scripts to generate AWS architecture diagrams using official AWS service icons for the N8n Queue Mode deployment.

## Overview

The diagrams are generated using the [diagrams](https://diagrams.mingrammer.com/) library, which provides official AWS architecture icons. This creates professional, publication-ready diagrams that are more visually appealing than text-based representations.

## Generated Diagrams

The script generates 6 comprehensive architecture diagrams:

1. **aws_n8n_architecture_overview.png** - High-level Queue Mode architecture showing N8n Main, Worker, and Browserless services with complete system flow
2. **aws_n8n_architecture_comprehensive.png** - Detailed view of all components including EFS, S3, Cloud Map service discovery, and serverless resources
3. **aws_n8n_network_architecture.png** - Detailed multi-AZ network architecture with VPC, subnets, routing, and service placement
4. **aws_n8n_security_architecture.png** - Security groups, IAM roles, and access control patterns for Queue Mode services
5. **aws_n8n_monitoring.png** - CloudWatch monitoring, SNS alerting, and observability configuration
6. **aws_n8n_queue_architecture.png** - Queue Mode workflow diagram showing job processing flow between Main service, Bull Queue, Worker services, and Browserless

## Prerequisites

### System Dependencies

**macOS:**
```bash
brew install graphviz
```

**Ubuntu/Debian:**
```bash
sudo apt-get install graphviz
```

**Red Hat/CentOS:**
```bash
sudo yum install graphviz
```

### Python Dependencies

Python 3.7 or higher is required.

```bash
pip install -r requirements.txt
```

Or install manually:
```bash
pip install diagrams==0.23.4 graphviz==0.20.1
```

## Usage

### Generate All Diagrams

Simply run the Python script:

```bash
python3 generate_aws_diagrams.py
```

### Output

The script will generate 6 PNG files in the current directory:
- `aws_n8n_architecture_overview.png`
- `aws_n8n_architecture_comprehensive.png`
- `aws_n8n_network_architecture.png`
- `aws_n8n_security_architecture.png`
- `aws_n8n_monitoring.png`
- `aws_n8n_queue_architecture.png`

Each diagram uses official AWS architecture icons and follows AWS diagramming best practices.

## Customization

To modify the diagrams, edit `generate_aws_diagrams.py`:

- **Change output format**: Modify the `filename` parameter (supports PNG, JPG, SVG, PDF)
- **Adjust layout**: Change the `direction` parameter ("TB" for top-to-bottom, "LR" for left-to-right)
- **Add services**: Import additional services from `diagrams.aws.*` modules
- **Modify styling**: Update the `graph_attr` dictionary

## Architecture Details

The diagrams reflect the actual Terragrunt configuration from `prod/terragrunt/new-vpc/terragrunt.hcl`:

### N8n Queue Mode Architecture

- **N8n Main Service**: Web UI, workflow management, job enqueuing (FARGATE_SPOT, desired count: 1)
- **N8n Worker Service**: Process queued jobs, execute workflows (FARGATE_SPOT, desired count: 1-3, auto-scaling)
- **Browserless Service**: Headless Chromium for web automation (WebSocket port 3000, FARGATE_SPOT)

### Infrastructure Components

- **Compute**: ECS Fargate with FARGATE_SPOT capacity provider
- **Containers**: n8nio/n8n:latest, browserless/chrome:latest
- **Database**: Aurora Serverless v2 PostgreSQL 17.5 (0.5-1 ACU, AWS-managed Multi-AZ)
- **Cache & Queue**: ElastiCache Valkey Serverless (Bull Queue backend, AWS-managed Multi-AZ)
- **Storage**: EFS for shared files (/home/node/.n8n), S3 for binary data
- **Service Discovery**: AWS Cloud Map (browserless.local internal DNS)
- **Load Balancer**: Application Load Balancer with HTTPS/SSL termination (routes to Main service only)
- **DNS**: Route53 with ACM SSL certificate
- **Network**: VPC (10.0.0.0/16) with multi-AZ public/private subnets
- **Routing**: NAT Gateway and Internet Gateway

### Key Features

- **Queue Mode**: Separate Main and Worker services for better scalability
- **Multi-AZ High Availability**: AWS-managed for Aurora and Valkey Serverless
- **Auto-scaling**: Worker services scale based on queue depth (1-3 tasks)
- **Service Discovery**: AWS Cloud Map for Browserless internal DNS resolution
- **Shared Storage**: EFS mounted to both Main and Worker services
- **Binary Data Storage**: S3 for large workflow artifacts
- **Encrypted Data**: At rest and in transit for all services
- **CloudWatch Monitoring**: Comprehensive logging and metrics
- **Security**: Security groups and IAM role-based access control for each service

## Troubleshooting

### Graphviz Not Found

If you get a "Graphviz executables not found" error:
```bash
# macOS
brew install graphviz

# Or check if it's installed but not in PATH
which dot
```

### Import Errors

If you get import errors for `diagrams`:
```bash
pip install --upgrade diagrams graphviz
```

### Permission Issues

If the script can't write files:
```bash
chmod +x generate_aws_diagrams.py
# Or run with appropriate permissions
sudo python3 generate_aws_diagrams.py
```

## Additional Resources

- [Diagrams Documentation](https://diagrams.mingrammer.com/)
- [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/)
- [Original Mermaid Diagrams](aws-architecture-diagrams.md)

## Queue Mode Benefits

The N8n Queue Mode architecture provides several advantages:

1. **Horizontal Scaling**: Worker services can scale independently from the Main service based on queue depth
2. **Resource Optimization**: Main service handles UI/API, workers handle compute-intensive jobs
3. **Better Reliability**: Job failures don't affect the web UI
4. **Cost Efficiency**: Scale workers only when needed, keep Main service minimal
5. **Performance**: Parallel job execution across multiple worker instances

## Serverless Components

The architecture leverages AWS serverless services for cost optimization and high availability:

- **Aurora Serverless v2**: Auto-scales from 0.5 to 1 ACU, AWS-managed Multi-AZ failover
- **Valkey Serverless**: Auto-scales based on usage, AWS-managed Multi-AZ replication
- **FARGATE_SPOT**: ~70% cost savings compared to on-demand Fargate

## Comparison with Mermaid Diagrams

This repository also contains `aws-architecture-diagrams.md` with 7 text-based Mermaid diagrams. The Python-generated diagrams offer:

- ✅ Official AWS service icons
- ✅ Professional, publication-ready quality
- ✅ Better visual clarity for Queue Mode architecture
- ✅ Shows serverless resource representation accurately
- ✅ Easier to customize programmatically

The Mermaid diagrams provide:

- ✅ More detailed component descriptions and data flows
- ✅ Sequence diagrams showing Queue Mode workflow execution
- ✅ Can be embedded in Markdown
- ✅ No installation dependencies
- ✅ Version control friendly (text-based)

Both approaches complement each other for different use cases.
