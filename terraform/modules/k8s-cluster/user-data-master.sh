#!/bin/bash
set -euxo pipefail

# This script initializes a Kubernetes master node

# Variables
K8S_VERSION="${kubernetes_version}"
CLUSTER_NAME="${cluster_name}"
POD_NETWORK_CIDR="${pod_network_cidr}"
CLUSTER_INTERNAL_SSH_PUB="${cluster_internal_ssh_pub}"
NODE_NAME="${node_name}"
PARTICIPANT_NAME="${participant_name}"

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting Kubernetes Master Node Setup ==="
echo "Kubernetes Version: $K8S_VERSION"
echo "Cluster Name: $CLUSTER_NAME"
echo "Pod Network CIDR: $POD_NETWORK_CIDR"
echo "Node Name: $NODE_NAME"

# Set hostname
hostnamectl set-hostname "$NODE_NAME"
echo "127.0.0.1 $NODE_NAME" >> /etc/hosts

# Update system
apt-get update
apt-get upgrade -y

# Disable swap (required by Kubernetes)
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load required kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Set required sysctl parameters
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install containerd
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

# Install Kubernetes components
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Enable kubelet
systemctl enable kubelet

# Get private IP
PRIVATE_IP=$(hostname -I | awk '{print $1}')

# Initialize Kubernetes cluster
kubeadm init \
    --pod-network-cidr=$POD_NETWORK_CIDR \
    --apiserver-advertise-address=$PRIVATE_IP \
    --node-name=$NODE_NAME \
    --ignore-preflight-errors=NumCPU

# Configure kubectl for ubuntu user
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# Configure internal SSH key for cluster communication
echo "$CLUSTER_INTERNAL_SSH_PUB" >> /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys
chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys

# Configure kubectl for root
export KUBECONFIG=/etc/kubernetes/admin.conf

# Install Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Wait for Calico to be ready
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s || true

# Generate and save join command for workers
kubeadm token create --print-join-command > /home/ubuntu/kubeadm-join-command.sh
chmod +x /home/ubuntu/kubeadm-join-command.sh
chown ubuntu:ubuntu /home/ubuntu/kubeadm-join-command.sh

# Create a simple script to display cluster info
cat <<'SCRIPT' > /home/ubuntu/cluster-info.sh
#!/bin/bash
echo "================================"
echo "Kubernetes Cluster Information"
echo "================================"
echo ""
echo "Cluster Name: $CLUSTER_NAME"
echo "Master Node: $(hostname)"
echo "Private IP: $(hostname -I | awk '{print $1}')"
echo ""
echo "Get cluster status:"
echo "  kubectl get nodes"
echo "  kubectl get pods --all-namespaces"
echo ""
echo "Join command for worker nodes:"
cat /home/ubuntu/kubeadm-join-command.sh
SCRIPT

chmod +x /home/ubuntu/cluster-info.sh
chown ubuntu:ubuntu /home/ubuntu/cluster-info.sh

# Install useful tools
apt-get update
apt-get install -y htop vim net-tools figlet

# Create custom MOTD
rm -f /etc/update-motd.d/*
cat > /etc/update-motd.d/00-custom-header << 'MOTD_SCRIPT'
#!/bin/bash
figlet -w 80 "K8s Master" 2>/dev/null || echo "=== Kubernetes Master Node ==="
MOTD_SCRIPT

cat > /etc/update-motd.d/10-node-info << 'MOTD_SCRIPT'
#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get system info
HOSTNAME=$$(hostname)
PRIVATE_IP=$$(hostname -I | awk '{print $$1}')
PUBLIC_IP=$$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "N/A")
K8S_VERSION=$$(kubectl version --short 2>/dev/null | grep Server | awk '{print $$3}' || echo "Not available yet")

echo -e "$${BLUE}╔════════════════════════════════════════════════════════════════╗$${NC}"
echo -e "$${BLUE}║$${NC}  $${CYAN}Node Information$${NC}                                             $${BLUE}║$${NC}"
echo -e "$${BLUE}╠════════════════════════════════════════════════════════════════╣$${NC}"
echo -e "$${BLUE}║$${NC}  $${GREEN}Participant:$${NC}    PARTICIPANT_PLACEHOLDER                      $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}  $${GREEN}Node Name:$${NC}      $$HOSTNAME                                    $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}  $${GREEN}Role:$${NC}           Master (Control Plane)                      $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}  $${GREEN}Private IP:$${NC}     $$PRIVATE_IP                                 $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}  $${GREEN}Public IP:$${NC}      $$PUBLIC_IP                                  $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}  $${GREEN}K8s Version:$${NC}    $$K8S_VERSION                                $${BLUE}║$${NC}"
echo -e "$${BLUE}╠════════════════════════════════════════════════════════════════╣$${NC}"
echo -e "$${BLUE}║$${NC}  $${YELLOW}Useful Commands:$${NC}                                            $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}    kubectl get nodes                                          $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}    kubectl get pods --all-namespaces                          $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}    /home/ubuntu/cluster-info.sh                               $${BLUE}║$${NC}"
echo -e "$${BLUE}╚════════════════════════════════════════════════════════════════╝$${NC}"
echo ""

# Show cluster status
if command -v kubectl &> /dev/null; then
    echo -e "$${CYAN}Cluster Nodes:$${NC}"
    kubectl get nodes 2>/dev/null | head -n 10 || echo "Cluster not ready yet"
    echo ""
fi
MOTD_SCRIPT

# Replace participant placeholder
sed -i "s/PARTICIPANT_PLACEHOLDER/$PARTICIPANT_NAME/g" /etc/update-motd.d/10-node-info

chmod +x /etc/update-motd.d/*

# Disable default Ubuntu MOTD
chmod -x /etc/update-motd.d/10-help-text 2>/dev/null || true
chmod -x /etc/update-motd.d/50-motd-news 2>/dev/null || true
chmod -x /etc/update-motd.d/95-hwe-eol 2>/dev/null || true

echo "=== Kubernetes Master Node Setup Complete ==="
echo "Run '/home/ubuntu/cluster-info.sh' to see cluster information"
