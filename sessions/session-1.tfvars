# Session 1 Configuration
# Simple setup with 1 master only

# AWS Region
aws_region = "eu-west-1"

# Session Configuration (IMPORTANT for cost tracking and workspace naming)
session_name = "session-1"

# VPC Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"]

# Security Configuration
allowed_ssh_cidrs = ["0.0.0.0/0"]
allowed_api_cidrs = ["0.0.0.0/0"]

# EC2 Instance Types
instance_type_master = "t3.medium"  # 2 vCPU, 4 GB RAM
instance_type_worker = "t3.small"   # 2 vCPU, 2 GB RAM

# Cluster Configuration
worker_count       = 0  # No workers - master only
kubernetes_version = "1.28"

# Project Name
project_name = "k8s-lab"
