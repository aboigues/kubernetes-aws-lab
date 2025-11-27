terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = "lab"
    }
  }
}

# Data source to read SSH public keys from participants directory
locals {
  participants_dir = "../participants"

  # Read all .pub files and extract participant names
  ssh_key_files = fileset(local.participants_dir, "*.pub")

  # Create a map of participant name to SSH public key
  participants = {
    for file in local.ssh_key_files :
    replace(file, ".pub", "") => file
    if file != "README.md" && file != "example.user.pub"
  }

  # Read SSH keys content
  ssh_keys = {
    for name, file in local.participants :
    name => trimspace(file("${local.participants_dir}/${file}"))
  }
}

# Shared VPC for all clusters
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  project_name       = var.project_name
}

# Create isolated K8s cluster for each participant
module "k8s_cluster" {
  source   = "./modules/k8s-cluster"
  for_each = local.participants

  participant_name   = each.key
  ssh_public_key     = local.ssh_keys[each.key]

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  instance_type_master = var.instance_type_master
  instance_type_worker = var.instance_type_worker
  worker_count         = var.worker_count
  kubernetes_version   = var.kubernetes_version

  project_name = var.project_name
}
