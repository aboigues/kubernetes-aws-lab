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
    tags = merge(
      {
        Project     = var.project_name
        ManagedBy   = "Terraform"
        Environment = "lab"
      },
      var.session_name != "" ? {
        Session = var.session_name
      } : {}
    )
  }
}

# Data source to read SSH public keys from participants directory
locals {
  participants_dir = "../participants"

  # Determine the directory to use based on session_name
  session_dir = var.session_name != "" ? "${local.participants_dir}/${var.session_name}" : local.participants_dir

  # Read all .pub files from the appropriate directory
  ssh_key_files = var.session_name != "" ? fileset(local.session_dir, "*.pub") : fileset(local.participants_dir, "*.pub")

  # Create a map of participant name to SSH public key
  # Transform filename from "prenom.nom.pub" to discrete format "prenom.no"
  participants = {
    for file in local.ssh_key_files :
    local.discrete_names[file] => file
    if file != "README.md" && file != "example.user.pub"
  }

  # Generate discrete participant names (prenom + 2 letters of nom)
  # Format: prenom.nom.pub -> prenom.no
  discrete_names = {
    for file in local.ssh_key_files :
    file => (
      length(split(".", replace(file, ".pub", ""))) >= 2 ?
      "${split(".", replace(file, ".pub", ""))[0]}.${substr(split(".", replace(file, ".pub", ""))[1], 0, 2)}" :
      replace(file, ".pub", "")
    )
  }

  # Read SSH keys content
  ssh_keys = {
    for name, file in local.participants :
    name => trimspace(file("${local.session_dir}/${file}"))
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

  project_name       = var.project_name
  session_name       = var.session_name
  allowed_ssh_cidrs  = var.allowed_ssh_cidrs
  allowed_api_cidrs  = var.allowed_api_cidrs
}
