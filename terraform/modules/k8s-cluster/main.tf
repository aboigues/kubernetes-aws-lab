# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for K8s cluster
resource "aws_security_group" "k8s_cluster" {
  name        = "${var.project_name}-${var.participant_name}-k8s-sg"
  description = "Security group for ${var.participant_name} Kubernetes cluster"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access"
  }

  # Kubernetes API server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.allowed_api_cidrs
    description = "Kubernetes API server"
  }

  # etcd
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
    description = "etcd server client API"
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
    description = "Kubelet API"
  }

  # kube-scheduler
  ingress {
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    self        = true
    description = "kube-scheduler"
  }

  # kube-controller-manager
  ingress {
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    self        = true
    description = "kube-controller-manager"
  }

  # NodePort Services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NodePort Services"
  }

  # Flannel/Calico (CNI)
  ingress {
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    self        = true
    description = "Flannel VXLAN"
  }

  # Allow all traffic within cluster
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "All traffic within cluster"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(
    {
      Name        = "${var.project_name}-${var.participant_name}-k8s-sg"
      Participant = var.participant_name
    },
    var.session_name != "" ? { Session = var.session_name } : {}
  )
}

# SSH Key pair for the participant
resource "aws_key_pair" "participant" {
  key_name   = "${var.project_name}-${var.participant_name}"
  public_key = var.ssh_public_key

  tags = merge(
    {
      Name        = "${var.project_name}-${var.participant_name}"
      Participant = var.participant_name
    },
    var.session_name != "" ? { Session = var.session_name } : {}
  )
}

# Master node
resource "aws_instance" "master" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type_master
  key_name      = aws_key_pair.participant.key_name

  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.k8s_cluster.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data-master.sh", {
    kubernetes_version = var.kubernetes_version
    cluster_name       = "${var.project_name}-${var.participant_name}"
    pod_network_cidr   = "10.${100 + local.participant_cidr_offset}.0.0/16"
  })

  tags = merge(
    {
      Name        = "${var.project_name}-${var.participant_name}-master"
      Participant = var.participant_name
      Role        = "master"
      Cluster     = "${var.project_name}-${var.participant_name}"
    },
    var.session_name != "" ? { Session = var.session_name } : {}
  )
}

# Worker nodes
resource "aws_instance" "worker" {
  count = var.worker_count

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type_worker
  key_name      = aws_key_pair.participant.key_name

  subnet_id              = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]
  vpc_security_group_ids = [aws_security_group.k8s_cluster.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data-worker.sh", {
    kubernetes_version = var.kubernetes_version
    master_private_ip  = aws_instance.master.private_ip
  })

  tags = merge(
    {
      Name        = "${var.project_name}-${var.participant_name}-worker-${count.index + 1}"
      Participant = var.participant_name
      Role        = "worker"
      Cluster     = "${var.project_name}-${var.participant_name}"
    },
    var.session_name != "" ? { Session = var.session_name } : {}
  )

  depends_on = [aws_instance.master]
}

# Local variable to generate unique CIDR offset for each participant
locals {
  # Use a hash of the participant name to generate a unique but deterministic offset (0-155)
  # This ensures each participant gets a unique pod network CIDR: 10.100-255.0.0/16
  participant_cidr_offset = abs(substr(md5(var.participant_name), 0, 2)) % 156
}
