# AWS N8n Architecture Diagrams

Based on the Terragrunt configuration in `prod/terragrunt/new-vpc/terragrunt.hcl`

## 1. High-Level Architecture Overview

```mermaid
graph TB
    subgraph Internet
        Users[Users/Clients]
        DNS[Route53 DNS<br/>n8n.example.com]
    end

    subgraph "AWS Cloud"
        subgraph "VPC (10.0.0.0/16)"
            subgraph "Public Subnets (Multi-AZ)"
                IGW[Internet Gateway]
                ALB[Application Load Balancer<br/>Port 443 HTTPS]
                NAT[NAT Gateway]
            end
            
            subgraph "Private Subnets (Multi-AZ)"
                subgraph "ECS Fargate Cluster - Queue Mode"
                    Main[N8n Main Service<br/>Web UI + Enqueue Jobs<br/>FARGATE_SPOT<br/>Desired Count: 1]
                    Worker[N8n Worker Service<br/>Process Queued Jobs<br/>FARGATE_SPOT<br/>Desired Count: 1-3]
                    Browserless[Browserless Service<br/>Headless Chrome<br/>WebSocket Port 3000<br/>FARGATE_SPOT]
                end
                
                subgraph "Storage Layer"
                    EFS[EFS<br/>Shared Storage<br/>/home/node/.n8n]
                    S3[S3 Bucket<br/>Binary Data Storage]
                end
                
                subgraph "Database Layer"
                    RDS[(Aurora Serverless v2<br/>PostgreSQL 17.5<br/>0.5-1 ACU<br/>AWS Managed HA)]
                end
                
                subgraph "Cache & Queue Layer"
                    Cache[(ElastiCache Valkey<br/>Serverless<br/>Bull Queue Backend<br/>AWS Managed HA)]
                end
                
                subgraph "Service Discovery"
                    CloudMap[AWS Cloud Map<br/>browserless.local<br/>Internal DNS]
                end
            end
        end
        
        ACM[AWS Certificate Manager<br/>SSL/TLS Certificate]
    end

    Users -->|HTTPS| DNS
    DNS -->|Resolves to| ALB
    ALB -->|SSL Termination| ACM
    ALB -->|Target Group| Main
    Main -->|Enqueue Jobs| Cache
    Worker -->|Process Jobs| Cache
    Main -->|Query/Store| RDS
    Worker -->|Query/Store| RDS
    Main -->|Shared Files| EFS
    Worker -->|Shared Files| EFS
    Main -->|Binary Data| S3
    Worker -->|Binary Data| S3
    Worker -->|WebSocket| Browserless
    Worker -->|DNS Lookup| CloudMap
    CloudMap -.->|Resolves| Browserless
    Main -->|Outbound Internet| NAT
    Worker -->|Outbound Internet| NAT
    Browserless -->|Outbound Internet| NAT
    NAT --> IGW
    IGW --> Internet

    style Users fill:#e1f5ff
    style DNS fill:#ff9900
    style ALB fill:#ff9900
    style Main fill:#ff9900
    style Worker fill:#ff9900
    style Browserless fill:#ff9900
    style RDS fill:#3b48cc
    style Cache fill:#c925d1
    style EFS fill:#1e8900
    style S3 fill:#e05243
    style CloudMap fill:#ff9900
    style NAT fill:#ff9900
    style IGW fill:#ff9900
    style ACM fill:#ff9900
```

## 2. Detailed Network Architecture

```mermaid
graph TB
    subgraph "Region: AWS"
        subgraph "VPC: 10.0.0.0/16"
            IGW[Internet Gateway]
            
            subgraph "Availability Zone A"
                subgraph "Public Subnet A"
                    ALB_A[ALB Node A]
                    NAT_A[NAT Gateway A]
                end
                
                subgraph "Private Subnet A"
                    Main_A[N8n Main Task A]
                    Worker_A[N8n Worker Task A]
                    Browser_A[Browserless Task A]
                    RDS_A[(Aurora Serverless v2<br/>AWS Managed HA<br/>Multi-AZ)]
                    Cache_A[(Valkey Serverless<br/>AWS Managed HA<br/>Multi-AZ)]
                    EFS_A[EFS Mount A]
                end
            end
            
            subgraph "Availability Zone B"
                subgraph "Public Subnet B"
                    ALB_B[ALB Node B]
                    NAT_B[NAT Gateway B<br/>Optional]
                end
                
                subgraph "Private Subnet B"
                    Main_B[N8n Main Task B<br/>Standby]
                    Worker_B[N8n Worker Task B]
                    Browser_B[Browserless Task B]
                    EFS_B[EFS Mount B]
                end
            end
            
            CloudMap[AWS Cloud Map<br/>Service Discovery]
            S3[S3 Bucket<br/>Region-wide]
        end
        
        RT_Public[Public Route Table<br/>0.0.0.0/0 → IGW]
        RT_Private_A[Private Route Table A<br/>0.0.0.0/0 → NAT-A]
        RT_Private_B[Private Route Table B<br/>0.0.0.0/0 → NAT-B]
    end

    IGW -.->|Routes| RT_Public
    RT_Public -.->|Associated| ALB_A
    RT_Public -.->|Associated| ALB_B
    RT_Private_A -.->|Associated| Main_A
    RT_Private_B -.->|Associated| Main_B
    
    NAT_A --> IGW
    NAT_B --> IGW
    
    ALB_A --> Main_A
    ALB_B --> Main_B
    
    Main_A --> RDS_A
    Main_B --> RDS_A
    Worker_A --> RDS_A
    Worker_B --> RDS_A
    
    Main_A --> Cache_A
    Main_B --> Cache_A
    Worker_A --> Cache_A
    Worker_B --> Cache_A
    
    Main_A --> EFS_A
    Main_B --> EFS_B
    Worker_A --> EFS_A
    Worker_B --> EFS_B
    
    Worker_A -.->|DNS Lookup| CloudMap
    Worker_B -.->|DNS Lookup| CloudMap
    CloudMap -.->|Resolves| Browser_A
    CloudMap -.->|Resolves| Browser_B
    
    Main_A --> S3
    Main_B --> S3
    Worker_A --> S3
    Worker_B --> S3

    style IGW fill:#ff9900
    style NAT_A fill:#ff9900
    style NAT_B fill:#ff9900
    style ALB_A fill:#ff9900
    style ALB_B fill:#ff9900
    style Main_A fill:#ff9900
    style Main_B fill:#ff9900
    style Worker_A fill:#ff9900
    style Worker_B fill:#ff9900
    style Browser_A fill:#ff9900
    style Browser_B fill:#ff9900
    style RDS_A fill:#3b48cc
    style Cache_A fill:#c925d1
    style EFS_A fill:#1e8900
    style EFS_B fill:#1e8900
    style S3 fill:#e05243
    style CloudMap fill:#ff9900
```

## 3. Data Flow Diagram - Queue Mode

```mermaid
sequenceDiagram
    participant User
    participant Route53
    participant ALB
    participant ACM
    participant Main as N8n Main
    participant Cache as Valkey Queue
    participant Worker as N8n Worker
    participant CloudMap
    participant Browserless
    participant RDS
    participant EFS
    participant S3
    participant NAT
    participant Internet

    User->>Route53: 1. DNS Query (n8n.example.com)
    Route53->>User: 2. Returns ALB IP
    User->>ALB: 3. HTTPS Request (Port 443)
    ALB->>ACM: 4. SSL/TLS Termination
    ACM->>ALB: 5. Certificate Validation
    ALB->>Main: 6. Forward Request (HTTP)
    
    Main->>RDS: 7. Query Workflow Data
    RDS->>Main: 8. Return Data
    Main->>EFS: 9. Read Shared Files
    EFS->>Main: 10. Return Files
    Main->>Cache: 11. Enqueue Job (Bull Queue)
    Main->>ALB: 12. HTTP Response
    ALB->>User: 13. HTTPS Response
    
    Worker->>Cache: 14. Poll for Jobs (Bull Queue)
    Cache->>Worker: 15. Return Job
    Worker->>RDS: 16. Query Job Data
    RDS->>Worker: 17. Return Data
    Worker->>CloudMap: 18. DNS Lookup (browserless.local)
    CloudMap->>Worker: 19. Return Browserless IP
    Worker->>Browserless: 20. WebSocket Connection (Port 3000)
    Browserless->>Worker: 21. Execute Browser Automation
    Worker->>EFS: 22. Write Results
    Worker->>S3: 23. Store Binary Data
    Worker->>Cache: 24. Mark Job Complete
    
    alt Outbound Internet Access
        Main->>NAT: 25a. Outbound Request
        Worker->>NAT: 25b. Outbound Request
        Browserless->>NAT: 25c. Outbound Request
        NAT->>Internet: 25d. Forward via IGW
        Internet->>NAT: 25e. Response
        NAT->>Main: 25f. Return Response
        NAT->>Worker: 25g. Return Response
        NAT->>Browserless: 25h. Return Response
    end
```

## 4. Security Architecture

```mermaid
graph TB
    subgraph "Security Groups & Network ACLs"
        subgraph "ALB Security Group"
            ALB_SG[Inbound: 443 HTTPS<br/>Outbound: Main Service Port]
        end
        
        subgraph "N8n Main Security Group"
            Main_SG[Inbound: From ALB<br/>Outbound: RDS:5432, Cache:6379, EFS:2049, S3:443, Internet]
        end
        
        subgraph "N8n Worker Security Group"
            Worker_SG[Inbound: None<br/>Outbound: RDS:5432, Cache:6379, EFS:2049, S3:443, Browserless:3000, Internet]
        end
        
        subgraph "Browserless Security Group"
            Browser_SG[Inbound: From Worker:3000<br/>Outbound: Internet]
        end
        
        subgraph "RDS Security Group"
            RDS_SG[Inbound: From Main:5432, Worker:5432<br/>Outbound: None]
        end
        
        subgraph "ElastiCache Security Group"
            Cache_SG[Inbound: From Main:6379, Worker:6379<br/>Outbound: None]
        end
        
        subgraph "EFS Security Group"
            EFS_SG[Inbound: From Main:2049, Worker:2049<br/>Outbound: None]
        end
    end
    
    subgraph "IAM Roles & Policies"
        Main_Task_Role[N8n Main Task Role<br/>- S3 Read/Write<br/>- CloudWatch Logs<br/>- Secrets Manager<br/>- EFS Access]
        Worker_Task_Role[N8n Worker Task Role<br/>- S3 Read/Write<br/>- CloudWatch Logs<br/>- Secrets Manager<br/>- EFS Access<br/>- Cloud Map Discovery]
        Browser_Task_Role[Browserless Task Role<br/>- CloudWatch Logs<br/>- Cloud Map Registration]
        ECS_Exec_Role[ECS Execution Role<br/>- ECR Pull<br/>- CloudWatch Logs<br/>- Secrets Manager]
    end
    
    ALB_SG -->|Allow| Main_SG
    Main_SG -->|Allow| RDS_SG
    Main_SG -->|Allow| Cache_SG
    Main_SG -->|Allow| EFS_SG
    Worker_SG -->|Allow| RDS_SG
    Worker_SG -->|Allow| Cache_SG
    Worker_SG -->|Allow| EFS_SG
    Worker_SG -->|Allow| Browser_SG
    
    Main_Task_Role -.->|Assumes| Main_SG
    Worker_Task_Role -.->|Assumes| Worker_SG
    Browser_Task_Role -.->|Assumes| Browser_SG
    ECS_Exec_Role -.->|Assumes| Main_SG
    ECS_Exec_Role -.->|Assumes| Worker_SG
    ECS_Exec_Role -.->|Assumes| Browser_SG

    style ALB_SG fill:#ff6b6b
    style Main_SG fill:#4ecdc4
    style Worker_SG fill:#4ecdc4
    style Browser_SG fill:#4ecdc4
    style RDS_SG fill:#45b7d1
    style Cache_SG fill:#96ceb4
    style EFS_SG fill:#1e8900
    style Main_Task_Role fill:#ffeaa7
    style Worker_Task_Role fill:#ffeaa7
    style Browser_Task_Role fill:#ffeaa7
    style ECS_Exec_Role fill:#dfe6e9
```

## 5. Component Details

### VPC Configuration
- **CIDR Block**: 10.0.0.0/16
- **Public Subnets**: Multi-AZ deployment with Internet Gateway
- **Private Subnets**: Multi-AZ deployment with NAT Gateway
- **DNS**: Enabled
- **DNS Hostnames**: Enabled

### N8n Queue Mode Services
#### N8n Main Service
- **Container Image**: n8nio/n8n:latest
- **Purpose**: Web UI, workflow management, job enqueuing
- **Capacity Provider**: FARGATE_SPOT (cost-optimized)
- **Desired Count**: 1 task
- **Environment**: EXECUTIONS_MODE=queue, QUEUE_BULL_REDIS_HOST, N8N_BINARY_DATA_MODE=filesystem
- **Health Check**: Via ALB target group

#### N8n Worker Service
- **Container Image**: n8nio/n8n:latest
- **Purpose**: Process queued jobs, execute workflows
- **Capacity Provider**: FARGATE_SPOT (cost-optimized)
- **Desired Count**: 1-3 tasks (auto-scaling based on queue depth)
- **Environment**: EXECUTIONS_MODE=queue, N8N_BINARY_DATA_MODE=filesystem
- **Health Check**: Queue polling health

#### Browserless Service
- **Container Image**: browserless/chrome:latest
- **Purpose**: Headless Chromium for web automation
- **Port**: 3000 (WebSocket)
- **Service Discovery**: AWS Cloud Map (browserless.local)
- **Capacity Provider**: FARGATE_SPOT
- **Desired Count**: 1 task

### Application Load Balancer
- **Scheme**: Internet-facing
- **Listeners**: HTTPS (Port 443)
- **SSL/TLS**: ACM Certificate
- **Target Group**: N8n Main Service only
- **Health Checks**: HTTP/HTTPS endpoint

### Aurora Serverless v2
- **Engine**: PostgreSQL 17.5
- **Capacity**: Min 0.5 ACU, Max 1 ACU
- **High Availability**: AWS-managed Multi-AZ (single serverless resource)
- **Backup**: Automated daily backups
- **Encryption**: At rest and in transit
- **Purpose**: Workflow definitions, execution history, credentials

### ElastiCache Valkey Serverless
- **Engine**: Valkey (Redis-compatible)
- **Type**: Serverless (auto-scaling)
- **High Availability**: AWS-managed Multi-AZ (single serverless resource)
- **Purpose**: Bull Queue backend for job queue management
- **Encryption**: In transit and at rest

### EFS (Elastic File System)
- **Purpose**: Shared storage for workflow files
- **Mount Path**: /home/node/.n8n
- **Access**: Mounted to both Main and Worker services
- **Encryption**: At rest and in transit

### S3 Bucket
- **Purpose**: Binary data storage for large workflow artifacts
- **Access**: N8n Main and Worker services
- **Encryption**: Server-side encryption (SSE-S3)
- **Lifecycle**: Optional policies for cost optimization

### AWS Cloud Map
- **Purpose**: Service discovery for internal DNS
- **Namespace**: browserless.local
- **Target**: Browserless service IP addresses
- **Access**: N8n Worker service for WebSocket connections

### Route53 & ACM (Optional)
- **DNS**: Custom domain (n8n.example.com)
- **Certificate**: ACM SSL/TLS certificate
- **Auto-renewal**: Managed by AWS

### NAT Gateway
- **Purpose**: Outbound internet access for private subnets
- **Deployment**: Per availability zone
- **Elastic IP**: Attached for static public IP

## 6. Cost Optimization Features

```mermaid
graph LR
    subgraph "Cost Optimization Strategies"
        A[FARGATE_SPOT<br/>~70% savings] --> B[Aurora Serverless v2<br/>Pay per ACU]
        B --> C[Valkey Serverless<br/>Pay per use]
        C --> D[Low Min Capacity<br/>0.5 ACU Aurora]
        D --> E[Queue Mode<br/>Scale workers only]
        E --> F[EFS + S3<br/>Cost-effective storage]
        F --> G[Single Main Service<br/>Multiple Workers]
    end

    style A fill:#90EE90
    style B fill:#90EE90
    style C fill:#90EE90
    style D fill:#90EE90
    style E fill:#90EE90
    style F fill:#90EE90
    style G fill:#90EE90
```

## 7. High Availability & Scaling

```mermaid
graph TB
    subgraph "High Availability"
        subgraph "Multi-AZ Deployment"
            A[ALB across 2+ AZs]
            B[ECS Tasks can span AZs]
            C[Aurora Multi-AZ Option]
            D[ElastiCache Replica Nodes]
        end
        
        subgraph "Auto Scaling"
            E[ECS Service Auto Scaling<br/>CPU/Memory Targets]
            F[Aurora ACU Auto Scaling<br/>0.5-1 ACU]
        end
        
        subgraph "Fault Tolerance"
            G[ALB Health Checks]
            H[ECS Task Replacement]
            I[Aurora Failover < 30s]
        end
    end

    A --> E
    B --> E
    C --> F
    E --> G
    F --> G
    G --> H
    H --> I

    style A fill:#FFD700
    style B fill:#FFD700
    style C fill:#FFD700
    style D fill:#FFD700
    style E fill:#87CEEB
    style F fill:#87CEEB
    style G fill:#98FB98
    style H fill:#98FB98
    style I fill:#98FB98
```

## Key Observations

1. **Fully Serverless Architecture**: Uses FARGATE_SPOT, Aurora Serverless v2, and managed services
2. **Cost-Optimized**: Minimal resources with SPOT instances and low ACU settings
3. **Scalable**: Can scale ECS tasks and Aurora ACUs based on demand
4. **Secure**: Private subnets for compute and data layers, with ALB in public subnet
5. **Resilient**: Multi-AZ deployment with automatic failover capabilities
6. **Production-Ready**: Includes SSL/TLS, custom domain support, and monitoring

## Infrastructure Components Summary

| Component | Type | Purpose | High Availability |
|-----------|------|---------|-------------------|
| VPC | Network | Isolated network environment | Regional |
| Public Subnets | Network | Host ALB and NAT Gateway | Multi-AZ |
| Private Subnets | Network | Host ECS, RDS, ElastiCache | Multi-AZ |
| Internet Gateway | Network | Internet access for public subnets | Highly available |
| NAT Gateway | Network | Outbound internet for private subnets | Per AZ |
| Application Load Balancer | Compute | Traffic distribution and SSL termination | Multi-AZ |
| ECS Fargate | Compute | N8n container orchestration | Multi-AZ |
| Aurora Serverless v2 | Database | PostgreSQL database | Multi-AZ optional |
| ElastiCache Valkey | Cache | Redis-compatible caching | Multi-AZ optional |
| Route53 | DNS | Domain name resolution | Global |
| ACM | Security | SSL/TLS certificates | Regional |
| Security Groups | Security | Firewall rules | Regional |
| IAM Roles | Security | Access control | Global |

## Deployment Characteristics

- **Infrastructure as Code**: Terragrunt + Terraform
- **Provisioning Time**: ~15-20 minutes
- **Estimated Monthly Cost**: $50-150 (varies by usage)
- **Maintenance**: Fully managed services, minimal operational overhead
- **Monitoring**: CloudWatch integration for logs and metrics
