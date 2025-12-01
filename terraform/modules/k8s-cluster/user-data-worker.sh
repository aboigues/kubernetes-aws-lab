#!/bin/bash
set -euxo pipefail

# This script initializes a Kubernetes worker node

# Variables
K8S_VERSION="${kubernetes_version}"
MASTER_IP="${master_private_ip}"
CLUSTER_INTERNAL_SSH_KEY="${cluster_internal_ssh_key}"

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting Kubernetes Worker Node Setup ==="
echo "Kubernetes Version: $K8S_VERSION"
echo "Master IP: $MASTER_IP"

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

# Configure internal SSH key for cluster communication
mkdir -p /root/.ssh
cat <<EOF > /root/.ssh/cluster_internal_key
$CLUSTER_INTERNAL_SSH_KEY
EOF
chmod 600 /root/.ssh/cluster_internal_key

# Also configure for ubuntu user
mkdir -p /home/ubuntu/.ssh
cat <<EOF > /home/ubuntu/.ssh/cluster_internal_key
$CLUSTER_INTERNAL_SSH_KEY
EOF
chmod 600 /home/ubuntu/.ssh/cluster_internal_key
chown ubuntu:ubuntu /home/ubuntu/.ssh/cluster_internal_key

# Wait for master node to be ready and get join command
echo "Waiting for master node to be ready..."
max_attempts=60
attempt=0

# Temporarily disable exit-on-error for the wait loop
set +e
while [ $attempt -lt $max_attempts ]; do
    ssh -i /root/.ssh/cluster_internal_key -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$MASTER_IP "test -f /home/ubuntu/kubeadm-join-command.sh" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "Master node is ready!"
        scp -i /root/.ssh/cluster_internal_key -o StrictHostKeyChecking=no ubuntu@$MASTER_IP:/home/ubuntu/kubeadm-join-command.sh /tmp/kubeadm-join-command.sh
        break
    fi
    echo "Master not ready yet, waiting... (attempt $((attempt+1))/$max_attempts)"
    sleep 10
    ((attempt++))
done
# Re-enable exit-on-error
set -e

if [ -f /tmp/kubeadm-join-command.sh ]; then
    # Join the cluster
    bash /tmp/kubeadm-join-command.sh
    echo "Successfully joined the cluster!"

    # Configure kubectl for ubuntu user to access the cluster from worker
    echo "Configuring kubectl for ubuntu user..."
    mkdir -p /home/ubuntu/.kube
    set +e
    scp -i /home/ubuntu/.ssh/cluster_internal_key -o StrictHostKeyChecking=no ubuntu@$MASTER_IP:/home/ubuntu/.kube/config /home/ubuntu/.kube/config
    if [ $? -eq 0 ]; then
        chown -R ubuntu:ubuntu /home/ubuntu/.kube
        echo "kubectl configured successfully!"
    else
        echo "Warning: Could not copy kubectl config from master (this is normal if master is still initializing)"
        echo "You can manually copy it later with: scp ubuntu@$MASTER_IP:/home/ubuntu/.kube/config ~/.kube/config"
    fi
    set -e
else
    echo "ERROR: Could not retrieve join command from master node"
    echo "You will need to manually join this node to the cluster"
    echo "On the master node, run: kubeadm token create --print-join-command"
    echo "Then run the output command on this worker node"
fi

# Install useful tools
apt-get install -y htop vim net-tools

echo "=== Kubernetes Worker Node Setup Complete ==="
