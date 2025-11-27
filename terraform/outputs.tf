output "vpc_id" {
  description = "ID of the shared VPC"
  value       = module.vpc.vpc_id
}

output "clusters" {
  description = "Information about each participant's cluster"
  value = {
    for name, cluster in module.k8s_cluster : name => {
      master_public_ip  = cluster.master_public_ip
      master_private_ip = cluster.master_private_ip
      worker_ips        = cluster.worker_private_ips
      ssh_command       = "ssh -i ~/.ssh/id_ed25519 ubuntu@${cluster.master_public_ip}"
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
