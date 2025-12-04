output "vpc_id" {
  description = "ID of the shared VPC"
  value       = module.vpc.vpc_id
}

output "clusters" {
  description = "Information about each participant's cluster"
  value = {
    for name, cluster in module.k8s_cluster : name => {
      master_public_ip   = cluster.master_public_ip
      master_private_ip  = cluster.master_private_ip
      worker_private_ips = cluster.worker_private_ips
      worker_public_ips  = cluster.worker_public_ips
      worker_ips         = cluster.worker_private_ips  # Keep for backward compatibility
      ssh_command        = "ssh -i ~/.ssh/id_ed25519 ubuntu@${cluster.master_public_ip}"
    }
  }
}

output "participant_access_info" {
  description = "Access information for each participant (formatted)"
  value = join("\n\n", [
    for name, cluster in module.k8s_cluster :
    <<-EOT
    Participant: ${name}
    Master IP: ${cluster.master_public_ip}
    SSH Command: ssh ubuntu@${cluster.master_public_ip}
    Worker Nodes: ${cluster.worker_count}
    EOT
  ])
}

output "session_info" {
  description = "Session information for cost tracking and management"
  value = {
    session_name       = var.session_name != "" ? var.session_name : "default"
    participant_count  = length(module.k8s_cluster)
    total_instances    = length(module.k8s_cluster) * (1 + var.worker_count)
    aws_cost_explorer_filter = var.session_name != "" ? "Tag: Session = ${var.session_name}" : "Tag: Project = ${var.project_name}"
  }
}

output "instance_type_master" {
  description = "EC2 instance type used for master nodes"
  value       = var.instance_type_master
}

output "instance_type_worker" {
  description = "EC2 instance type used for worker nodes"
  value       = var.instance_type_worker
}

output "worker_count" {
  description = "Number of worker nodes per cluster"
  value       = var.worker_count
}

output "availability_zones" {
  description = "Availability zones in use"
  value       = var.availability_zones
}
