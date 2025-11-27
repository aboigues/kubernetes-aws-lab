variable "participant_name" {
  description = "Name of the participant"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for the participant"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "instance_type_master" {
  description = "EC2 instance type for master node"
  type        = string
}

variable "instance_type_worker" {
  description = "EC2 instance type for worker nodes"
  type        = string
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "session_name" {
  description = "Training session identifier"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH into instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_api_cidrs" {
  description = "List of CIDR blocks allowed to access Kubernetes API"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
