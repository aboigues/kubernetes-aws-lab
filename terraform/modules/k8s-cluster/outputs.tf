output "master_public_ip" {
  description = "Public IP of the master node"
  value       = aws_instance.master.public_ip
}

output "master_private_ip" {
  description = "Private IP of the master node"
  value       = aws_instance.master.private_ip
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = aws_instance.worker[*].private_ip
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = aws_instance.worker[*].public_ip
}

output "worker_count" {
  description = "Number of worker nodes"
  value       = var.worker_count
}

output "cluster_name" {
  description = "Name of the cluster"
  value       = "${var.project_name}-${var.participant_name}"
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.k8s_cluster.id
}
