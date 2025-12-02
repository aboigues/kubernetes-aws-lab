#!/bin/bash
set -euxo pipefail

# This script initializes a Kubernetes worker node

# Variables
K8S_VERSION="${kubernetes_version}"
MASTER_IP="${master_private_ip}"
CLUSTER_INTERNAL_SSH_KEY="${cluster_internal_ssh_key}"
NODE_NAME="${node_name}"
WORKER_INDEX="${worker_index}"
PARTICIPANT_NAME="${participant_name}"

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting Kubernetes Worker Node Setup ==="
echo "Kubernetes Version: $K8S_VERSION"
echo "Master IP: $MASTER_IP"
echo "Node Name: $NODE_NAME"
echo "Worker Index: $WORKER_INDEX"

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
    # Join the cluster with custom node name
    bash /tmp/kubeadm-join-command.sh --node-name=$NODE_NAME
    echo "Successfully joined the cluster as $NODE_NAME!"

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
apt-get update
apt-get install -y htop vim net-tools figlet

# Create custom MOTD
rm -f /etc/update-motd.d/*
cat > /etc/update-motd.d/00-custom-header << 'MOTD_SCRIPT'
#!/bin/bash
figlet -w 80 "K8s Worker" 2>/dev/null || echo "=== Kubernetes Worker Node ==="
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
MASTER_IP="MASTER_IP_PLACEHOLDER"

echo -e "$${BLUE}╔════════════════════════════════════════════════════════════════╗$${NC}"
echo -e "$${BLUE}║$${NC}  $${CYAN}Node Information$${NC}                                             $${BLUE}║$${NC}"
echo -e "$${BLUE}╠════════════════════════════════════════════════════════════════╣$${NC}"
echo -e "$${BLUE}║$${NC}  $${GREEN}Participant:$${NC}    PARTICIPANT_PLACEHOLDER                      $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}  $${GREEN}Node Name:$${NC}      $$HOSTNAME                                    $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}  $${GREEN}Role:$${NC}           Worker Node (Worker Index: WORKER_INDEX_PLACEHOLDER) $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}  $${GREEN}Private IP:$${NC}     $$PRIVATE_IP                                 $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}  $${GREEN}Public IP:$${NC}      $$PUBLIC_IP                                  $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}  $${GREEN}Master IP:$${NC}      $$MASTER_IP                                  $${BLUE}║$${NC}"
echo -e "$${BLUE}╠════════════════════════════════════════════════════════════════╣$${NC}"
echo -e "$${BLUE}║$${NC}  $${YELLOW}Useful Commands:$${NC}                                            $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}    kubectl get nodes                                          $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}    kubectl get pods --all-namespaces                          $${BLUE}║$${NC}"
echo -e "$${BLUE}║$${NC}    ssh ubuntu@\$$MASTER_IP  # Connect to master               $${BLUE}║$${NC}"
echo -e "$${BLUE}╚════════════════════════════════════════════════════════════════╝$${NC}"
echo ""

# Show cluster status if kubectl is configured
if [ -f /home/ubuntu/.kube/config ]; then
    echo -e "$${CYAN}Cluster Nodes:$${NC}"
    kubectl get nodes 2>/dev/null | head -n 10 || echo "kubectl not configured yet - run from master"
    echo ""
fi
MOTD_SCRIPT

# Replace placeholders
sed -i "s/PARTICIPANT_PLACEHOLDER/$PARTICIPANT_NAME/g" /etc/update-motd.d/10-node-info
sed -i "s/WORKER_INDEX_PLACEHOLDER/$WORKER_INDEX/g" /etc/update-motd.d/10-node-info
sed -i "s/MASTER_IP_PLACEHOLDER/$MASTER_IP/g" /etc/update-motd.d/10-node-info

chmod +x /etc/update-motd.d/*

# Disable default Ubuntu MOTD
chmod -x /etc/update-motd.d/10-help-text 2>/dev/null || true
chmod -x /etc/update-motd.d/50-motd-news 2>/dev/null || true
chmod -x /etc/update-motd.d/95-hwe-eol 2>/dev/null || true

echo "=== Kubernetes Worker Node Setup Complete ==="
