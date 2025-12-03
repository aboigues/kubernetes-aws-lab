# Session 3 Configuration
# Large setup with 1 master and 5 workers

# AWS Region
aws_region = "eu-west-1"

# Session Configuration (IMPORTANT for cost tracking and workspace naming)
session_name = "session-3"

# VPC Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"]

# Security Configuration
allowed_ssh_cidrs = ["0.0.0.0/0"]
allowed_api_cidrs = ["0.0.0.0/0"]

# EC2 Instance Types
instance_type_master = "t3.large"    # 2 vCPU, 8 GB RAM - larger for more workers
instance_type_worker = "t3.medium"   # 2 vCPU, 4 GB RAM - larger workers

# Cluster Configuration
worker_count       = 5  # 5 worker nodes
kubernetes_version = "1.28"

# Project Name
project_name = "k8s-lab"
