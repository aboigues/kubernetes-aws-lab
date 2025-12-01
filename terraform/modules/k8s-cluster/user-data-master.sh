#!/bin/bash
set -euxo pipefail

# This script initializes a Kubernetes master node

# Variables
K8S_VERSION="${kubernetes_version}"
CLUSTER_NAME="${cluster_name}"
POD_NETWORK_CIDR="${pod_network_cidr}"
CLUSTER_INTERNAL_SSH_PUB="${cluster_internal_ssh_pub}"

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting Kubernetes Master Node Setup ==="
echo "Kubernetes Version: $K8S_VERSION"
echo "Cluster Name: $CLUSTER_NAME"
echo "Pod Network CIDR: $POD_NETWORK_CIDR"

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
    --node-name=$(hostname) \
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
apt-get install -y htop vim net-tools

echo "=== Kubernetes Master Node Setup Complete ==="
echo "Run '/home/ubuntu/cluster-info.sh' to see cluster information"
