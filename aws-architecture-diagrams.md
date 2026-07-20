# AWS N8n Architecture Diagrams

Based on the Terragrunt configuration in `stg/terragrunt/new-vpc/terragrunt.hcl` and `prod/terragrunt/new-vpc/terragrunt.hcl`

## 1. High-Level Architecture Overview

```mermaid
graph TB
    subgraph Internet
        Users[Users/Clients]
        EntraID[Microsoft Entra ID<br/>SAML SSO]
        DNS[Route53 DNS<br/>n8n.example.com]
    end

    subgraph "AWS Cloud"
        subgraph "Edge Security"
            WAF[AWS WAF<br/>Web ACL]
        end
        
        subgraph "VPC (10.0.0.0/16)"
            subgraph "Public Subnets (Multi-AZ)"
                IGW[Internet Gateway]
                ALB[Application Load Balancer<br/>Port 443 HTTPS]
                NAT[NAT Gateway]
            end
            
            subgraph "Private Subnets (Multi-AZ)"
                subgraph "ECS Fargate Cluster - Queue Mode"
                    subgraph "Main Service"
                        Main[N8n Main Service<br/>Web UI + Enqueue Jobs<br/>FARGATE_SPOT<br/>Desired Count: 1]
                        TaskRunnerMain[Task Runner Sidecar<br/>n8nio/runners:latest]
                    end
                    subgraph "Worker Service"
                        Worker[N8n Worker Service<br/>Process Queued Jobs<br/>FARGATE_SPOT<br/>Desired Count: 2]
                        TaskRunnerWorker[Task Runner Sidecar<br/>n8nio/runners:latest]
                    end
                    Browserless[Browserless Service<br/>Headless Chrome<br/>WebSocket Port 3000<br/>FARGATE_SPOT]
                end
                
                subgraph "Storage Layer"
                    EFS[EFS<br/>Shared Storage<br/>/home/node/.n8n]
                    S3[S3 Bucket<br/>Binary Data Storage]
                end
                
                subgraph "Database Layer"
                    RDS[(Aurora Serverless v2<br/>PostgreSQL 17.7<br/>0.5-4 ACU<br/>AWS Managed HA)]
                end
                
                subgraph "Cache & Queue Layer"
                    Cache[(ElastiCache Valkey<br/>Serverless<br/>5000 ECPU/s, 1GB<br/>Bull Queue Backend<br/>AWS Managed HA)]
                end
                
                subgraph "Service Discovery"
                    CloudMap[AWS Cloud Map<br/>browserless.local<br/>Internal DNS]
                end
            end
        end
        
        ACM[AWS Certificate Manager<br/>SSL/TLS Certificate]
        Secrets[AWS Secrets Manager<br/>DB Credentials<br/>Valkey Credentials<br/>Task Runner Token]
    end

    Users -->|Authenticate| EntraID
    EntraID -->|SAML Response| DNS
    DNS -->|Resolves to| WAF
    WAF -->|Filter Traffic| ALB
    ALB -->|SSL Termination| ACM
    ALB -->|Target Group| Main
    Main <-->|Sidecar| TaskRunnerMain
    Worker <-->|Sidecar| TaskRunnerWorker
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
    Main -->|Read Secrets| Secrets
    Worker -->|Read Secrets| Secrets
    Main -->|Outbound Internet| NAT
    Worker -->|Outbound Internet| NAT
    Browserless -->|Outbound Internet| NAT
    NAT --> IGW
    IGW --> Internet

    style Users fill:#e1f5ff
    style EntraID fill:#0078d4
    style DNS fill:#ff9900
    style WAF fill:#ff9900
    style ALB fill:#ff9900
    style Main fill:#ff9900
    style Worker fill:#ff9900
    style TaskRunnerMain fill:#ff6600
    style TaskRunnerWorker fill:#ff6600
    style Browserless fill:#ff9900
    style RDS fill:#3b48cc
    style Cache fill:#c925d1
    style EFS fill:#1e8900
    style S3 fill:#e05243
    style CloudMap fill:#ff9900
    style NAT fill:#ff9900
    style IGW fill:#ff9900
    style ACM fill:#ff9900
    style Secrets fill:#dd344c
```

## 2. Detailed Network Architecture

```mermaid
graph TB
    subgraph "Region: AWS"
        subgraph "VPC: 10.0.0.0/16"
            IGW[Internet Gateway]
            
            subgraph "Availability Zone A (10.0.0.0/24, 10.0.4.0/24)"
                subgraph "Public Subnet A"
                    ALB_A[ALB Node A]
                    NAT_A[NAT Gateway]
                end
                
                subgraph "Private Subnet A"
                    Main_A[N8n Main Task A]
                    Runner_A[Task Runner A]
                    Worker_A[N8n Worker Task A]
                    RunnerW_A[Task Runner A]
                    Browser_A[Browserless Task A]
                    RDS_A[(Aurora Serverless v2<br/>AWS Managed HA<br/>Multi-AZ)]
                    Cache_A[(Valkey Serverless<br/>5000 ECPU/s<br/>AWS Managed HA<br/>Multi-AZ)]
                    EFS_A[EFS Mount A]
                end
            end
            
            subgraph "Availability Zone B (10.0.1.0/24, 10.0.5.0/24)"
                subgraph "Public Subnet B"
                    ALB_B[ALB Node B]
                end
                
                subgraph "Private Subnet B"
                    Worker_B[N8n Worker Task B]
                    RunnerW_B[Task Runner B]
                    Browser_B[Browserless Task B]
                    EFS_B[EFS Mount B]
                end
            end
            
            subgraph "Availability Zone C (10.0.2.0/24, 10.0.6.0/24)"
                subgraph "Public Subnet C"
                    ALB_C[ALB Node C]
                end
                
                subgraph "Private Subnet C"
                    EFS_C[EFS Mount C]
                end
            end
            
            CloudMap[AWS Cloud Map<br/>Service Discovery]
            S3[S3 Bucket<br/>Region-wide]
        end
        
        RT_Public[Public Route Table<br/>0.0.0.0/0 → IGW]
        RT_Private[Private Route Table<br/>0.0.0.0/0 → NAT]
    end

    IGW -.->|Routes| RT_Public
    RT_Public -.->|Associated| ALB_A
    RT_Public -.->|Associated| ALB_B
    RT_Public -.->|Associated| ALB_C
    RT_Private -.->|Associated| Main_A
    RT_Private -.->|Associated| Worker_A
    RT_Private -.->|Associated| Worker_B
    
    NAT_A --> IGW
    
    ALB_A --> Main_A
    ALB_B --> Main_A
    ALB_C --> Main_A
    
    Main_A <--> Runner_A
    Worker_A <--> RunnerW_A
    Worker_B <--> RunnerW_B
    
    Main_A --> RDS_A
    Worker_A --> RDS_A
    Worker_B --> RDS_A
    
    Main_A --> Cache_A
    Worker_A --> Cache_A
    Worker_B --> Cache_A
    
    Main_A --> EFS_A
    Worker_A --> EFS_A
    Worker_B --> EFS_B
    
    Worker_A -.->|DNS Lookup| CloudMap
    Worker_B -.->|DNS Lookup| CloudMap
    CloudMap -.->|Resolves| Browser_A
    CloudMap -.->|Resolves| Browser_B
    
    Main_A --> S3
    Worker_A --> S3
    Worker_B --> S3

    style IGW fill:#ff9900
    style NAT_A fill:#ff9900
    style ALB_A fill:#ff9900
    style ALB_B fill:#ff9900
    style ALB_C fill:#ff9900
    style Main_A fill:#ff9900
    style Worker_A fill:#ff9900
    style Worker_B fill:#ff9900
    style Runner_A fill:#ff6600
    style RunnerW_A fill:#ff6600
    style RunnerW_B fill:#ff6600
    style Browser_A fill:#ff9900
    style Browser_B fill:#ff9900
    style RDS_A fill:#3b48cc
    style Cache_A fill:#c925d1
    style EFS_A fill:#1e8900
    style EFS_B fill:#1e8900
    style EFS_C fill:#1e8900
    style S3 fill:#e05243
    style CloudMap fill:#ff9900
```

## 3. Data Flow Diagram - Queue Mode with Microsoft Entra ID SSO

```mermaid
sequenceDiagram
    participant User
    participant EntraID as Microsoft Entra ID
    participant Route53
    participant WAF
    participant ALB
    participant ACM
    participant Main as N8n Main
    participant TaskRunner as Task Runner
    participant Cache as Valkey Queue
    participant Worker as N8n Worker
    participant CloudMap
    participant Browserless
    participant RDS
    participant EFS
    participant S3
    participant Secrets
    participant NAT
    participant Internet

    User->>EntraID: 1. Initiate SSO Login
    EntraID->>User: 2. SAML Authentication
    User->>Route53: 3. DNS Query (n8n.example.com)
    Route53->>User: 4. Returns ALB IP
    User->>WAF: 5. HTTPS Request with SAML Token
    WAF->>ALB: 6. Filter & Forward
    ALB->>ACM: 7. SSL/TLS Termination
    ACM->>ALB: 8. Certificate Validation
    ALB->>Main: 9. Forward Request (HTTP)
    
    Main->>Secrets: 10. Get DB/Cache Credentials
    Secrets->>Main: 11. Return Credentials
    Main->>RDS: 12. Query Workflow Data
    RDS->>Main: 13. Return Data
    Main->>EFS: 14. Read Shared Files
    EFS->>Main: 15. Return Files
    Main->>Cache: 16. Enqueue Job (Bull Queue)
    Main->>ALB: 17. HTTP Response
    ALB->>User: 18. HTTPS Response
    
    Worker->>Secrets: 19. Get Credentials + Task Runner Token
    Secrets->>Worker: 20. Return Credentials
    Worker->>Cache: 21. Poll for Jobs (Bull Queue)
    Cache->>Worker: 22. Return Job
    Worker->>TaskRunner: 23. Execute Task in Sidecar
    TaskRunner->>Worker: 24. Return Task Result
    Worker->>RDS: 25. Query Job Data
    RDS->>Worker: 26. Return Data
    Worker->>CloudMap: 27. DNS Lookup (browserless.local)
    CloudMap->>Worker: 28. Return Browserless IP
    Worker->>Browserless: 29. WebSocket Connection (Port 3000)
    Browserless->>Worker: 30. Execute Browser Automation
    Worker->>EFS: 31. Write Results
    Worker->>S3: 32. Store Binary Data
    Worker->>Cache: 33. Mark Job Complete
    
    alt Outbound Internet Access
        Main->>NAT: 34a. Outbound Request
        Worker->>NAT: 34b. Outbound Request
        Browserless->>NAT: 34c. Outbound Request
        NAT->>Internet: 34d. Forward via IGW
        Internet->>NAT: 34e. Response
        NAT->>Main: 34f. Return Response
    end
```

## 4. Security Architecture with Microsoft Entra ID

```mermaid
graph TB
    subgraph "Identity & Access"
        subgraph "Microsoft Entra ID (SSO)"
            EntraID[Microsoft Entra ID<br/>SAML 2.0 SSO]
            SAML[SAML Assertion<br/>User Identity + Roles]
            JIT[Just-in-Time<br/>Provisioning]
        end
        
        subgraph "AWS WAF"
            WAF[Web ACL<br/>Rate Limiting<br/>IP Filtering<br/>SQL Injection Protection]
        end
    end
    
    subgraph "Security Groups & Network ACLs"
        subgraph "ALB Security Group"
            ALB_SG[Inbound: 80, 443<br/>Outbound: VPC CIDR]
        end
        
        subgraph "N8n Main Security Group"
            Main_SG[Inbound: 5678 From ALB<br/>Outbound: RDS:5432, Cache:6379, EFS:2049, S3:443, Internet]
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
            EFS_SG[Inbound: From VPC:2049<br/>Outbound: None]
        end
    end
    
    subgraph "IAM Roles & Policies"
        Task_Role[ECS Task Role<br/>- S3 Read/Write<br/>- CloudWatch Logs<br/>- Secrets Manager Read<br/>- EFS Access<br/>- Cloud Map Discovery]
        Exec_Role[ECS Execution Role<br/>- ECR Pull<br/>- CloudWatch Logs<br/>- Secrets Manager Read]
    end
    
    subgraph "Secrets Management"
        Secrets[AWS Secrets Manager]
        DB_Secret[DB Credentials<br/>username, password, host]
        Valkey_Secret[Valkey Credentials<br/>username, password]
        Runner_Secret[Task Runner Token<br/>64-char auth token]
    end
    
    subgraph "Encryption"
        KMS[AWS KMS<br/>Encryption Keys]
        TLS[TLS 1.2+<br/>In-Transit Encryption]
        SSE[Server-Side Encryption<br/>At-Rest]
    end
    
    EntraID --> SAML --> JIT
    JIT --> WAF --> ALB_SG
    
    ALB_SG -->|Allow| Main_SG
    Main_SG -->|Allow| RDS_SG
    Main_SG -->|Allow| Cache_SG
    Main_SG -->|Allow| EFS_SG
    Worker_SG -->|Allow| RDS_SG
    Worker_SG -->|Allow| Cache_SG
    Worker_SG -->|Allow| EFS_SG
    Worker_SG -->|Allow| Browser_SG
    
    Task_Role -.->|Assumes| Main_SG
    Task_Role -.->|Assumes| Worker_SG
    Exec_Role -.->|Manages| Task_Role
    
    Secrets --> DB_Secret
    Secrets --> Valkey_Secret
    Secrets --> Runner_Secret
    
    KMS --> TLS
    KMS --> SSE

    style EntraID fill:#0078d4
    style SAML fill:#0078d4
    style JIT fill:#0078d4
    style WAF fill:#ff9900
    style ALB_SG fill:#ff6b6b
    style Main_SG fill:#4ecdc4
    style Worker_SG fill:#4ecdc4
    style Browser_SG fill:#4ecdc4
    style RDS_SG fill:#45b7d1
    style Cache_SG fill:#96ceb4
    style EFS_SG fill:#1e8900
    style Task_Role fill:#ffeaa7
    style Exec_Role fill:#dfe6e9
    style Secrets fill:#dd344c
    style KMS fill:#dd344c
```

## 5. Component Details

### Microsoft Entra ID Integration
- **Protocol**: SAML 2.0 Single Sign-On
- **Just-in-Time Provisioning**: Automatic user creation on first login
- **Role Mapping**: Instance roles provisioned from Entra ID claims
- **Session Management**: Configurable via N8N_SSO_* environment variables

### VPC Configuration
- **CIDR Block**: 10.0.0.0/16
- **Public Subnets**: 10.0.4.0/24, 10.0.5.0/24, 10.0.6.0/24 (Multi-AZ)
- **Private Subnets**: 10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24 (Multi-AZ)
- **NAT Gateway**: Single gateway for cost optimization
- **DNS**: Enabled
- **DNS Hostnames**: Enabled

### N8n Queue Mode Services

#### N8n Main Service
- **Container Image**: n8nio/n8n:latest
- **Task Runner Sidecar**: n8nio/runners:latest
- **Purpose**: Web UI, workflow management, job enqueuing
- **Capacity Provider**: FARGATE_SPOT (cost-optimized)
- **Desired Count**: 1 task
- **CPU/Memory**: 1024 CPU, 2048 MB (+ Task Runner resources if enabled)
- **Environment**: EXECUTIONS_MODE=queue, N8N_RUNNERS_ENABLED=true
- **Health Check**: Via ALB target group (/healthz)

#### N8n Worker Service
- **Container Image**: n8nio/n8n:latest
- **Task Runner Sidecar**: n8nio/runners:latest
- **Purpose**: Process queued jobs, execute workflows
- **Capacity Provider**: FARGATE_SPOT (cost-optimized)
- **Desired Count**: 2 tasks (configurable)
- **CPU/Memory**: 1024 CPU, 2048 MB (+ Task Runner resources)
- **Concurrency**: 20 concurrent executions per worker
- **Pool Size**: 20 DB connections per worker

#### Task Runner (n8n v2.0+)
- **Container Image**: n8nio/runners:latest
- **Purpose**: Isolated execution environment for workflow tasks
- **Mode**: External (sidecar container)
- **Auto Shutdown**: 15 seconds timeout
- **Authentication**: 64-character token via Secrets Manager

#### Browserless Service
- **Container Image**: browserless/chrome:latest
- **Purpose**: Headless Chromium for web automation
- **Port**: 3000 (WebSocket)
- **Service Discovery**: AWS Cloud Map (browserless.local)
- **Capacity Provider**: FARGATE_SPOT
- **Desired Count**: 1 task

### Application Load Balancer
- **Scheme**: Internet-facing
- **Listeners**: HTTP (80) redirects to HTTPS (443)
- **SSL/TLS**: ACM Certificate (TLS 1.2+)
- **Target Group**: N8n Main Service only
- **Health Checks**: /healthz endpoint
- **Idle Timeout**: 300 seconds
- **Stickiness**: Enabled (3600s cookie duration)

### AWS WAF (Optional)
- **Purpose**: Edge protection
- **Features**: Rate limiting, IP filtering, SQL injection protection
- **Integration**: Associated with ALB via web ACL ARN

### Aurora Serverless v2
- **Engine**: PostgreSQL 17.7
- **Capacity**: Min 0.5 ACU, Max 4 ACU
- **High Availability**: AWS-managed Multi-AZ
- **Backup**: Automated daily backups
- **Encryption**: At rest (KMS) and in transit (SSL)
- **Purpose**: Workflow definitions, execution history, credentials
- **Connection Pool**: Main (10), Worker (20)

### ElastiCache Valkey Serverless
- **Engine**: Valkey 8 (Redis-compatible)
- **Type**: Serverless (auto-scaling)
- **Capacity**: 5000 ECPU/s max, 1 GB storage
- **High Availability**: AWS-managed Multi-AZ
- **Purpose**: Bull Queue backend for job queue management
- **Encryption**: In transit (TLS) and at rest
- **Authentication**: User/password via Secrets Manager

### EFS (Elastic File System)
- **Purpose**: Shared storage for workflow files
- **Mount Path**: /home/node/.n8n
- **Access**: Mounted to both Main and Worker services
- **Encryption**: At rest and in transit
- **Access Point**: UID/GID 1000, permissions 777

### S3 Bucket
- **Purpose**: Binary data storage for large workflow artifacts
- **Access**: N8n Main and Worker services via IAM role
- **Encryption**: Server-side encryption (AES-256)
- **Versioning**: Enabled
- **Lifecycle**: 30-day noncurrent version expiration

### AWS Secrets Manager
- **Secrets**:
  - DB Credentials (username, password, host, port, dbname)
  - Valkey Credentials (username, password)
  - Task Runner Auth Token (64-char token)
- **Recovery Window**: Configurable (default 7 days)

### AWS Cloud Map
- **Purpose**: Service discovery for internal DNS
- **Namespace**: {prefix}.local
- **Target**: Browserless service IP addresses
- **Access**: N8n Worker service for WebSocket connections

### Route53 & ACM (Optional)
- **DNS**: Custom domain (e.g., n8n.example.com)
- **Certificate**: ACM SSL/TLS certificate
- **Auto-renewal**: Managed by AWS

### CloudWatch Logs
- **Log Groups**:
  - {prefix}-logs (Main service, 180 days)
  - {prefix}-worker-logs (Worker service, 180 days)
  - {prefix}-task-runner-main-logs (Task Runner, 180 days)
  - {prefix}-task-runner-worker-logs (Task Runner, 180 days)
  - {prefix}-browserless-logs (Browserless, 180 days)
  - /aws/elasticache/{prefix}-valkey (Valkey, 180 days)

## 6. Cost Optimization Features

```mermaid
graph LR
    subgraph "Cost Optimization Strategies"
        A[FARGATE_SPOT<br/>~70% savings] --> B[Aurora Serverless v2<br/>Pay per ACU<br/>0.5-4 scaling]
        B --> C[Valkey Serverless<br/>Pay per ECPU<br/>5000 max]
        C --> D[Single NAT Gateway<br/>Cost optimization]
        D --> E[Queue Mode<br/>Scale workers only]
        E --> F[EFS + S3<br/>Cost-effective storage]
        F --> G[Container Insights<br/>Disabled by default]
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
            A[ALB across 3 AZs]
            B[ECS Tasks span AZs]
            C[Aurora Multi-AZ<br/>AWS Managed]
            D[Valkey Multi-AZ<br/>AWS Managed]
            E[EFS Multi-AZ<br/>AWS Managed]
        end
        
        subgraph "Auto Scaling"
            F[ECS Service Auto Scaling<br/>CPU/Memory Targets]
            G[Aurora ACU Auto Scaling<br/>0.5-4 ACU]
            H[Valkey ECPU Auto Scaling<br/>0-5000 ECPU/s]
        end
        
        subgraph "Fault Tolerance"
            I[ALB Health Checks<br/>/healthz endpoint]
            J[ECS Task Replacement<br/>Automatic]
            K[Aurora Failover<br/><30 seconds]
            L[NAT Gateway<br/>Regional resilience]
        end
    end

    A --> F
    B --> F
    C --> G
    D --> H
    E --> L
    F --> I
    G --> J
    H --> K
    I --> J
    J --> K
    K --> L

    style A fill:#FFD700
    style B fill:#FFD700
    style C fill:#FFD700
    style D fill:#FFD700
    style E fill:#FFD700
    style F fill:#87CEEB
    style G fill:#87CEEB
    style H fill:#87CEEB
    style I fill:#98FB98
    style J fill:#98FB98
    style K fill:#98FB98
    style L fill:#98FB98
```

## Key Observations

1. **Microsoft Entra ID SSO**: SAML 2.0 authentication with Just-in-Time provisioning
2. **Fully Serverless Architecture**: Uses FARGATE_SPOT, Aurora Serverless v2, Valkey Serverless
3. **Task Runner Support**: External task runners for isolated workflow execution (n8n v2.0+)
4. **Cost-Optimized**: Minimal resources with SPOT instances, low ACU settings, single NAT
5. **Scalable**: Can scale ECS tasks, Aurora ACUs, and Valkey ECPUs based on demand
6. **Secure**: AWS WAF, private subnets, encrypted secrets, TLS everywhere
7. **Resilient**: Multi-AZ deployment with automatic failover capabilities
8. **Production-Ready**: SSL/TLS, custom domain support, comprehensive monitoring

## Infrastructure Components Summary

| Component | Type | Purpose | High Availability |
|-----------|------|---------|-------------------|
| Microsoft Entra ID | Identity | SAML 2.0 SSO | Global |
| AWS WAF | Security | Edge protection | Regional |
| VPC | Network | Isolated network environment | Regional |
| Public Subnets | Network | Host ALB and NAT Gateway | Multi-AZ (3) |
| Private Subnets | Network | Host ECS, RDS, ElastiCache | Multi-AZ (3) |
| Internet Gateway | Network | Internet access for public subnets | Highly available |
| NAT Gateway | Network | Outbound internet for private subnets | Single (cost opt) |
| Application Load Balancer | Compute | Traffic distribution and SSL termination | Multi-AZ |
| ECS Fargate | Compute | N8n container orchestration | Multi-AZ |
| Task Runner | Compute | Isolated workflow execution | Per task |
| Aurora Serverless v2 | Database | PostgreSQL database | Multi-AZ (AWS managed) |
| ElastiCache Valkey | Cache | Redis-compatible queue backend | Multi-AZ (AWS managed) |
| EFS | Storage | Shared file storage | Multi-AZ (AWS managed) |
| S3 | Storage | Binary data storage | Regional |
| Route53 | DNS | Domain name resolution | Global |
| ACM | Security | SSL/TLS certificates | Regional |
| Secrets Manager | Security | Credential management | Regional |
| CloudWatch | Monitoring | Logs and metrics | Regional |
| Security Groups | Security | Firewall rules | Regional |
| IAM Roles | Security | Access control | Global |

## Deployment Characteristics

- **Infrastructure as Code**: Terragrunt + Terraform
- **Provisioning Time**: ~15-20 minutes
- **Estimated Monthly Cost**: $50-200 (varies by usage)
- **Maintenance**: Fully managed services, minimal operational overhead
- **Monitoring**: CloudWatch integration for logs and metrics (180 days retention)
- **n8n Version**: v2.0+ required for Task Runner support
