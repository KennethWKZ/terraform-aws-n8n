#!/usr/bin/env python3
"""
Generate AWS Architecture Diagrams with Official AWS Icons
Based on the Terragrunt configuration for N8n deployment with Queue Mode
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import ECS, Fargate
from diagrams.aws.database import Aurora, ElastiCache
from diagrams.aws.integration import SimpleNotificationServiceSns
from diagrams.aws.management import Cloudwatch, CloudwatchEventTimeBased
from diagrams.aws.network import ELB
from diagrams.aws.network import VPC  # Use VPC icon for Security Groups
from diagrams.aws.network import VPC as SecurityGroup
from diagrams.aws.network import (InternetGateway, NATGateway, PrivateSubnet,
                                  PublicSubnet, Route53, CloudMap)
from diagrams.aws.security import CertificateManager, IAMRole, SecretsManager, WAF
from diagrams.aws.storage import S3, EFS
from diagrams.azure.identity import \
    ActiveDirectory  # Microsoft Entra ID (formerly Azure AD)
from diagrams.onprem.client import Users
from diagrams.onprem.vcs import Git  # Git icon to represent Bitbucket

# Configuration
graph_attr = {
    "fontsize": "14",
    "bgcolor": "white",
    "pad": "0.5",
}

# Enhanced graph attributes for comprehensive diagram (better edge separation)
comprehensive_graph_attr = {
    "fontsize": "14",
    "bgcolor": "white",
    "pad": "2.5",
    "ranksep": "2.0",  # Significantly increase vertical separation between ranks
    "nodesep": "1.0",  # Significantly increase horizontal separation between nodes
    "splines": "spline",  # Use curved routing to prevent edge overlapping
    "concentrate": "false",  # Prevent Graphviz from bundling parallel edges
}

# Diagram 1: High-Level Architecture Overview with Queue Mode
with Diagram("N8n AWS Architecture - High Level Overview (Queue Mode)", 
             filename="aws_n8n_architecture_overview",
             direction="TB",
             graph_attr=graph_attr,
             show=False):
    
    users = Users("Users/Clients")
    
    with Cluster("AWS Cloud"):
        dns = Route53("Route53\nn8n.example.com")
        waf = WAF("AWS WAF\nWeb ACL\nFilters Traffic")
        acm = CertificateManager("ACM\nSSL Certificate")
        
        with Cluster("VPC (10.0.0.0/16)"):
            with Cluster("Public Subnets (Multi-AZ)"):
                igw = InternetGateway("Internet\nGateway")
                alb = ELB("Application\nLoad Balancer\nHTTPS:443")
                nat = NATGateway("NAT\nGateway")
            
            with Cluster("Private Subnets (Multi-AZ)"):
                with Cluster("ECS Fargate Cluster - Queue Mode"):
                    efs = EFS("EFS\nShared Storage\n/home/node/.n8n")
                    main = ECS("Main Service\nn8n Web UI\nQueues Jobs")
                    worker = Fargate("Worker Service\nn8n worker\nProcesses Jobs")
                    browserless = Fargate("Browserless\nChromium\nWebSocket:3000")
                    cloudmap = CloudMap("Service Discovery\nbrowserless.local")
                
                with Cluster("Database Layer"):
                    rds = Aurora("Aurora Serverless v2\nPostgreSQL 17.5\n0.5-1 ACU")
                
                with Cluster("Cache/Queue Layer"):
                    cache = ElastiCache("ElastiCache Valkey\nServerless\nBull Queue Backend")
                
                with Cluster("Storage"):
                    s3 = S3("S3 Bucket\nBinary Data")
    
    # Connections
    users >> Edge(label="HTTPS") >> dns
    dns >> Edge(label="resolves to") >> waf
    waf >> Edge(label="filtered traffic") >> alb
    alb >> Edge(label="SSL termination") >> acm
    alb >> Edge(label="target group") >> main
    
    # Queue mode flow
    main >> Edge(label="enqueues jobs", color="red") >> cache
    cache >> Edge(label="job processing", color="red") >> worker
    
    # Database connections
    main >> Edge(label="queries") >> rds
    worker >> Edge(label="queries") >> rds
    
    # EFS shared storage
    efs >> Edge(style="dashed", label="mount") >> main
    efs >> Edge(style="dashed", label="mount") >> worker
    
    # S3 binary data
    main >> Edge(label="binary data") >> s3
    worker >> Edge(label="binary data") >> s3
    
    # Outbound internet
    main >> Edge(label="outbound") >> nat >> igw
    worker >> Edge(label="outbound") >> nat >> igw
    
    # Browserless connections
    browserless >> Edge(label="registers") >> cloudmap
    main >> Edge(label="WebSocket\nws://browserless:3000", color="purple") >> browserless

# Diagram 2: Queue Mode Architecture Detail
with Diagram("N8n AWS Architecture - Queue Mode Detail",
             filename="aws_n8n_queue_architecture",
             direction="LR",
             graph_attr=graph_attr,
             show=False):
    
    with Cluster("ECS Fargate Cluster"):
        with Cluster("Main Service (Web UI)"):
            main_task = ECS("Main Instance\nConcurrency: 15\nPool Size: 10")
            
        with Cluster("Worker Service"):
            worker_task = Fargate("Worker Instance\nConcurrency: 50\nPool Size: 20")
        
        efs_storage = EFS("EFS Volume\nShared /home/node/.n8n")
    
    with Cluster("Queue Backend"):
        valkey = ElastiCache("ElastiCache Valkey\nServerless\nBull Queue")
    
    with Cluster("Database"):
        aurora = Aurora("Aurora Serverless v2\nPostgreSQL\nConnections pooled")
    
    with Cluster("External Storage"):
        s3_binary = S3("S3 Bucket\nBinary Data")
    
    # Queue flow
    main_task >> Edge(label="1. Enqueue\nworkflow execution", color="red", style="bold") >> valkey
    valkey >> Edge(label="2. Dequeue\njob for processing", color="red", style="bold") >> worker_task
    worker_task >> Edge(label="3. Update\nexecution status", color="blue") >> aurora
    
    # Shared storage
    efs_storage >> Edge(style="dashed", label="mount") >> main_task
    efs_storage >> Edge(style="dashed", label="mount") >> worker_task
    
    # Database connections
    main_task >> Edge(label="workflows,\nusers, settings", color="blue") >> aurora
    
    # S3 connections
    main_task >> Edge(label="store") >> s3_binary
    worker_task >> Edge(label="retrieve/store") >> s3_binary

# Diagram 3: Detailed Network Architecture
with Diagram("N8n AWS Architecture - Network Architecture",
             filename="aws_n8n_network_architecture",
             direction="TB",
             graph_attr=graph_attr,
             show=False):
    
    with Cluster("AWS Region"):
        igw = InternetGateway("Internet Gateway")
        
        with Cluster("VPC: 10.0.0.0/16"):
            with Cluster("Availability Zone A"):
                with Cluster("Public Subnet A"):
                    alb_a = ELB("ALB\nNode A")
                    nat_a = NATGateway("NAT\nGateway A")
                
                with Cluster("Private Subnet A"):
                    main_a = Fargate("Main\nTask A\nn8n UI")
                    worker_a = Fargate("Worker\nTask A")
                    browserless_a = Fargate("Browserless\nTask A\nChromium")
                    rds_a = Aurora("Aurora\nPrimary")
                    cache_a = ElastiCache("Valkey\nServerless")
                    efs_a = EFS("EFS\nMount A")
            
            with Cluster("Availability Zone B"):
                with Cluster("Public Subnet B"):
                    alb_b = ELB("ALB\nNode B")
                    nat_b = NATGateway("NAT\nGateway B")
                
                with Cluster("Private Subnet B"):
                    main_b = Fargate("Main\nTask B\nn8n UI")
                    worker_b = Fargate("Worker\nTask B")
                    browserless_b = Fargate("Browserless\nTask B\nChromium")
                    rds_b = Aurora("Aurora\nReplica")
                    cache_b = ElastiCache("Valkey\nServerless")
                    efs_b = EFS("EFS\nMount B")
        
        # Network connections
        igw >> nat_a
        igw >> nat_b
        alb_a >> main_a
        alb_b >> main_b
        
        # Database connections
        main_a >> rds_a
        main_b >> rds_a
        worker_a >> rds_a
        worker_b >> rds_a
        
        # Cache/Queue connections
        main_a >> cache_a
        main_b >> cache_a
        worker_a >> cache_a
        worker_b >> cache_b
        
        # Replication
        rds_a - Edge(style="dashed", label="replication") - rds_b
        cache_a - Edge(style="dashed", label="replication") - cache_b
        
        # EFS mounts
        efs_a - Edge(style="dashed") - main_a
        efs_a - Edge(style="dashed") - worker_a
        efs_b - Edge(style="dashed") - main_b
        efs_b - Edge(style="dashed") - worker_b
        
        # Browserless WebSocket connections
        main_a >> Edge(label="ws:3000", color="purple") >> browserless_a
        main_b >> Edge(label="ws:3000", color="purple") >> browserless_b

# Diagram 4: Security Architecture
with Diagram("N8n AWS Architecture - Security Architecture",
             filename="aws_n8n_security_architecture",
             direction="LR",
             graph_attr=graph_attr,
             show=False):
    
    with Cluster("Security Components"):
        waf = WAF("AWS WAF\nWeb ACL\nLayer 7\nProtection")
        
        with Cluster("Security Groups"):
            alb_sg = SecurityGroup("ALB SG\nInbound: 443\nOutbound: ECS")
            ecs_sg = SecurityGroup("ECS SG\nInbound: ALB\nOutbound: RDS, Cache, Browserless")
            browserless_sg = SecurityGroup("Browserless SG\nInbound: ECS:3000")
            rds_sg = SecurityGroup("RDS SG\nInbound: ECS:5432")
            cache_sg = SecurityGroup("Cache SG\nInbound: ECS:6379")
        
        with Cluster("IAM Roles"):
            task_role = IAMRole("ECS Task Role\nS3, EFS, CloudWatch,\nSecrets Manager")
            exec_role = IAMRole("ECS Execution Role\nECR, CloudWatch,\nSecrets Manager")
        
        secrets = SecretsManager("Secrets Manager\nDB Password\nRedis Token")
    
    with Cluster("Resources"):
        alb = ELB("ALB")
        main = ECS("Main ECS")
        worker = Fargate("Worker ECS")
        browserless = Fargate("Browserless")
        rds = Aurora("Aurora")
        cache = ElastiCache("ElastiCache")
        efs = EFS("EFS")
    
    # Security relationships
    waf >> Edge(label="protects") >> alb
    alb_sg >> alb
    ecs_sg >> main
    ecs_sg >> worker
    browserless_sg >> browserless
    rds_sg >> rds
    cache_sg >> cache
    
    task_role >> main
    task_role >> worker
    exec_role >> main
    exec_role >> worker
    
    main >> Edge(label="retrieve secrets", color="green") >> secrets
    worker >> Edge(label="retrieve secrets", color="green") >> secrets
    
    alb >> main
    main >> [rds, cache]
    worker >> [rds, cache]
    main >> Edge(label="WebSocket", color="purple") >> browserless
    
    # EFS connections
    efs >> Edge(style="dashed") >> main
    efs >> Edge(style="dashed") >> worker

# Diagram 5: Monitoring and Observability
with Diagram("N8n AWS Architecture - Monitoring",
             filename="aws_n8n_monitoring",
             direction="TB",
             graph_attr=graph_attr,
             show=False):
    
    with Cluster("Monitoring Stack"):
        cw = Cloudwatch("CloudWatch\nLogs & Metrics")
        sns = SimpleNotificationServiceSns("SNS\nAlerts")
    
        with Cluster("Monitored Resources"):
            alb = ELB("ALB\nMetrics")
            main = ECS("Main Service\nn8n Logs")
            worker = Fargate("Worker Service\nn8n-worker Logs")
            browserless = Fargate("Browserless\nContainer Logs")
            rds = Aurora("Aurora\nPerformance")
            cache = ElastiCache("Valkey Serverless\nMetrics")
    
    # Monitoring connections
    alb >> cw
    main >> cw
    worker >> cw
    browserless >> cw
    rds >> cw
    cache >> cw
    cw >> Edge(label="alarms") >> sns

# Diagram 6: Comprehensive Architecture (Overview + Networking + Security)
with Diagram("N8n AWS Architecture - Comprehensive View (Queue Mode)",
             filename="aws_n8n_architecture_comprehensive",
             direction="TB",
             graph_attr=comprehensive_graph_attr,
             show=False):
    
    users = Users("Users/Clients")
    entra_id = ActiveDirectory("Microsoft\nEntra ID\nSSO SAML")
    
    with Cluster("AWS Cloud"):
        dns = Route53("Route53\nn8n.example.com")
        waf = WAF("AWS WAF\nWeb ACL\nLayer 7 Protection")
        acm = CertificateManager("ACM\nSSL Certificate")
        
        with Cluster("VPC: 10.0.0.0/16"):
            igw = InternetGateway("Internet Gateway")
            
            with Cluster("Availability Zone A"):
                with Cluster("Public Subnet A: 10.0.1.0/24"):
                    nat_a = NATGateway("NAT\nGateway A")
                    alb_a = ELB("ALB\nNode A")
                    alb_sg_a = SecurityGroup("ALB SG\n0.0.0.0/0:443")
                
                with Cluster("Private Subnet A: 10.0.11.0/24"):
                    main_a = Fargate("Main\nTask A\nn8n UI\nQueues Jobs")
                    worker_a = Fargate("Worker\nTask A\nProcesses Jobs")
                    browserless_a = Fargate("Browserless\nTask A\nChromium")
                    ecs_sg_a = SecurityGroup("ECS SG A")
                    browserless_sg_a = SecurityGroup("Browserless\nSG A")
                    ecs_role_a = IAMRole("Task\nRole A")
            
            with Cluster("Availability Zone B"):
                with Cluster("Public Subnet B: 10.0.2.0/24"):
                    nat_b = NATGateway("NAT\nGateway B")
                    alb_b = ELB("ALB\nNode B")
                    alb_sg_b = SecurityGroup("ALB SG\n0.0.0.0/0:443")
                
                with Cluster("Private Subnet B: 10.0.12.0/24"):
                    main_b = Fargate("Main\nTask B\nn8n UI\nQueues Jobs")
                    worker_b = Fargate("Worker\nTask B\nProcesses Jobs")
                    browserless_b = Fargate("Browserless\nTask B\nChromium")
                    ecs_sg_b = SecurityGroup("ECS SG B")
                    browserless_sg_b = SecurityGroup("Browserless\nSG B")
                    ecs_role_b = IAMRole("Task\nRole B")
            
            with Cluster("Shared Storage"):
                efs_storage = EFS("EFS Volume\n/home/node/.n8n\nShared between\nMain & Worker")
            
            with Cluster("Security & Secrets"):
                secrets_mgr = SecretsManager("Secrets Manager\nDB Credentials\nRedis Auth Token\nUser Secrets")
            
            with Cluster("Service Discovery"):
                cloudmap_svc = CloudMap("AWS Cloud Map\nbrowserless.local\nInternal DNS")
            
            with Cluster("External Storage"):
                s3_binary = S3("S3 Bucket\nbinary-data")
            
            with Cluster("Database Layer (Multi-AZ)"):
                with Cluster("Aurora Serverless v2"):
                    aurora_serverless = Aurora("Aurora Serverless v2\nPostgreSQL 17.5\n(AWS-managed HA)")
                    rds_sg = SecurityGroup("RDS SG\nECS:5432")
                
                with Cluster("ElastiCache Valkey Serverless"):
                    valkey_serverless = ElastiCache("Valkey Serverless\nBull Queue Backend\n(AWS-managed HA)")
                    cache_sg = SecurityGroup("Cache SG\nECS:6379")
    
    # External Atlassian Cloud for Version Control
    with Cluster("Atlassian Cloud"):
        bitbucket = Git("Bitbucket\nVersion Control\nProjects & Workflows")
    
    # User traffic flow
    users >> Edge(label="HTTPS", style="bold", penwidth="5.0") >> dns
    dns >> Edge(label="resolves to", color="darkblue", penwidth="4.5") >> waf
    waf >> Edge(label="filtered traffic", color="red", penwidth="4.5") >> alb_a
    waf >> Edge(label="filtered traffic", color="red", penwidth="4.5") >> alb_b
    
    # SSL termination
    alb_a >> Edge(label="SSL cert", color="green", penwidth="4.0") >> acm
    alb_b >> Edge(label="SSL cert", color="green", penwidth="4.0") >> acm
    
    # Microsoft Entra ID SSO SAML authentication (redirect flow)
    dns >> Edge(label="redirect to login", color="purple", penwidth="5.0") >> entra_id
    entra_id >> Edge(label="start login", color="purple", penwidth="5.0") >> users
    users >> Edge(label="redirect after auth", color="purple", penwidth="5.0") >> dns

    # Security group associations
    alb_sg_a >> Edge(style="dashed", color="orange", penwidth="4.0") >> alb_a
    alb_sg_b >> Edge(style="dashed", color="orange", penwidth="4.0") >> alb_b
    ecs_sg_a >> Edge(style="dashed", color="orange", penwidth="4.0") >> main_a
    ecs_sg_a >> Edge(style="dashed", color="orange", penwidth="4.0") >> worker_a
    ecs_sg_b >> Edge(style="dashed", color="orange", penwidth="4.0") >> main_b
    ecs_sg_b >> Edge(style="dashed", color="orange", penwidth="4.0") >> worker_b
    browserless_sg_a >> Edge(style="dashed", color="orange", penwidth="4.0") >> browserless_a
    browserless_sg_b >> Edge(style="dashed", color="orange", penwidth="4.0") >> browserless_b
    rds_sg >> Edge(style="dashed", color="orange", penwidth="4.0") >> aurora_serverless
    cache_sg >> Edge(style="dashed", color="orange", penwidth="4.0") >> valkey_serverless
    
    # IAM role associations
    ecs_role_a >> Edge(style="dotted", color="purple", penwidth="4.0") >> main_a
    ecs_role_a >> Edge(style="dotted", color="purple", penwidth="4.0") >> worker_a
    ecs_role_b >> Edge(style="dotted", color="purple", penwidth="4.0") >> main_b
    ecs_role_b >> Edge(style="dotted", color="purple", penwidth="4.0") >> worker_b
    
    # Secrets Manager credential retrieval
    main_a >> Edge(label="get secrets", color="green", penwidth="4.5") >> secrets_mgr
    main_b >> Edge(label="get secrets", color="green", penwidth="4.5") >> secrets_mgr
    worker_a >> Edge(label="get secrets", color="green", penwidth="4.5") >> secrets_mgr
    worker_b >> Edge(label="get secrets", color="green", penwidth="4.5") >> secrets_mgr
    
    # EFS shared storage
    efs_storage >> Edge(label="mount", color="brown", penwidth="4.5", style="dashed") >> main_a
    efs_storage >> Edge(label="mount", color="brown", penwidth="4.5", style="dashed") >> main_b
    efs_storage >> Edge(label="mount", color="brown", penwidth="4.5", style="dashed") >> worker_a
    efs_storage >> Edge(label="mount", color="brown", penwidth="4.5", style="dashed") >> worker_b
    
    # S3 binary data storage
    main_a >> Edge(label="binary data", color="brown", penwidth="4.5") >> s3_binary
    main_b >> Edge(label="binary data", color="brown", penwidth="4.5") >> s3_binary
    worker_a >> Edge(label="binary data", color="brown", penwidth="4.5") >> s3_binary
    worker_b >> Edge(label="binary data", color="brown", penwidth="4.5") >> s3_binary
    
    # Service Discovery registration
    browserless_a >> Edge(label="register", color="teal", penwidth="4.5") >> cloudmap_svc
    browserless_b >> Edge(label="register", color="teal", penwidth="4.5") >> cloudmap_svc
    
    # Version control integration with Bitbucket
    main_a >> Edge(label="git sync", color="darkgreen", penwidth="4.5") >> bitbucket
    main_b >> Edge(label="git sync", color="darkgreen", penwidth="4.5") >> bitbucket
    
    # ALB to Main tasks only (Workers don't need ALB)
    alb_a >> Edge(label="target group", style="bold", penwidth="5.0") >> main_a
    alb_b >> Edge(label="target group", style="bold", penwidth="5.0") >> main_b
    
    # Queue flow - Main enqueues, Worker processes
    main_a >> Edge(label="enqueue jobs", color="red", penwidth="5.0") >> valkey_serverless
    main_b >> Edge(label="enqueue jobs", color="red", penwidth="5.0") >> valkey_serverless
    valkey_serverless >> Edge(label="dequeue jobs", color="red", penwidth="5.0") >> worker_a
    valkey_serverless >> Edge(label="dequeue jobs", color="red", penwidth="5.0") >> worker_b
    
    # Database connections
    main_a >> Edge(label="workflows/users", color="blue", penwidth="4.5") >> aurora_serverless
    main_b >> Edge(label="workflows/users", color="blue", penwidth="4.5") >> aurora_serverless
    worker_a >> Edge(label="execution status", color="blue", penwidth="4.5") >> aurora_serverless
    worker_b >> Edge(label="execution status", color="blue", penwidth="4.5") >> aurora_serverless
    
    # n8n to Browserless WebSocket connections (via Service Discovery DNS)
    main_a >> Edge(label="WebSocket\nws://browserless:3000", color="purple", penwidth="5.0") >> browserless_a
    main_b >> Edge(label="WebSocket\nws://browserless:3000", color="purple", penwidth="5.0") >> browserless_b
    
    # Outbound internet access
    main_a >> Edge(label="outbound", penwidth="4.0") >> nat_a
    main_b >> Edge(label="outbound", penwidth="4.0") >> nat_b
    worker_a >> Edge(label="outbound", penwidth="4.0") >> nat_a
    worker_b >> Edge(label="outbound", penwidth="4.0") >> nat_b
    nat_a >> Edge(penwidth="4.0") >> igw
    nat_b >> Edge(penwidth="4.0") >> igw

print("✅ AWS Architecture Diagrams generated successfully!")
print("\nGenerated files:")
print("  - aws_n8n_architecture_overview.png (Queue Mode)")
print("  - aws_n8n_queue_architecture.png (NEW - Queue Mode Detail)")
print("  - aws_n8n_network_architecture.png")
print("  - aws_n8n_security_architecture.png")
print("  - aws_n8n_monitoring.png")
print("  - aws_n8n_architecture_comprehensive.png (Queue Mode)")
print("\nThese diagrams use official AWS architecture icons and reflect the queue mode deployment.")
