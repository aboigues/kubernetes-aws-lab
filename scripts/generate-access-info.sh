#!/bin/bash

# Script to generate participant access information
# This script should be run from the terraform/ directory after a successful terraform apply

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Kubernetes AWS Lab - Participant Access Information ===${NC}\n"

# Check if terraform directory exists and has state
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo "Error: Terraform directory not found at $TERRAFORM_DIR"
    exit 1
fi

cd "$TERRAFORM_DIR"

if [ ! -f "terraform.tfstate" ]; then
    echo "Error: terraform.tfstate not found. Please run 'terraform apply' first."
    exit 1
fi

# Get session name if set
SESSION_NAME=$(terraform output -json 2>/dev/null | jq -r '.session_info.value.session_name // empty')

if [ -n "$SESSION_NAME" ]; then
    echo -e "${YELLOW}Session: ${SESSION_NAME}${NC}\n"
fi

# Get clusters output
CLUSTERS_JSON=$(terraform output -json clusters 2>/dev/null)

if [ -z "$CLUSTERS_JSON" ] || [ "$CLUSTERS_JSON" = "null" ]; then
    echo "No clusters found in terraform output."
    exit 0
fi

# Parse and display each participant's information
echo "$CLUSTERS_JSON" | jq -r '
to_entries[] |
"=================================================
Participant: \(.key)
=================================================
Master Node IP: \(.value.master_public_ip)
SSH Command: ssh ubuntu@\(.value.master_public_ip)

Worker Nodes: \(.value.worker_public_ips | length)
" +
(if (.value.worker_public_ips | length) > 0 then
  (.value.worker_public_ips | to_entries | map(
    "  Worker-\(.key + 1): \(.value)
    SSH: ssh ubuntu@\(.value)"
  ) | join("\n"))
else
  "  No worker nodes"
end) + "

Connection Instructions:
1. Connect to your master node:
   ssh ubuntu@\(.value.master_public_ip)

2. Connect to worker nodes (from your local machine):
" +
(if (.value.worker_public_ips | length) > 0 then
  (.value.worker_public_ips | to_entries | map(
    "   ssh ubuntu@\(.value)  # worker-\(.key + 1)"
  ) | join("\n"))
else
  "   No worker nodes available"
end) + "

3. Check cluster status:
   kubectl get nodes

4. View cluster info:
   /home/ubuntu/cluster-info.sh

"
'

echo -e "\n${GREEN}=== Email/Slack Message Template ===${NC}\n"

# Generate a template message for easy distribution
cat << 'EOF'
Hi Team,

Your Kubernetes lab environment is ready! Here are your access details:

EOF

echo "$CLUSTERS_JSON" | jq -r '
to_entries[] |
"Participant: \(.key)
Master IP: \(.value.master_public_ip)
SSH: ssh ubuntu@\(.value.master_public_ip)
Workers: \(.value.worker_public_ips | length) nodes
" +
(if (.value.worker_public_ips | length) > 0 then
  (.value.worker_public_ips | to_entries | map(
    "  Worker-\(.key + 1): \(.value)"
  ) | join("\n"))
else
  ""
end) + "
---"
'

cat << 'EOF'

To get started:
1. SSH into your master node using the command above
2. Run: kubectl get nodes
3. Run: /home/ubuntu/cluster-info.sh for cluster details

The environment will be available until [DATE/TIME].

Happy Learning!
EOF

echo -e "\n${GREEN}=== Individual Access Files ===${NC}\n"

# Create individual access files for each participant
ACCESS_DIR="$SCRIPT_DIR/../participant-access"
mkdir -p "$ACCESS_DIR"

echo "$CLUSTERS_JSON" | jq -r 'to_entries[] | @base64' | while read -r entry; do
    _jq() {
        echo "$entry" | base64 -d | jq -r "$1"
    }

    PARTICIPANT=$(_jq '.key')
    MASTER_IP=$(_jq '.value.master_public_ip')
    WORKER_COUNT=$(_jq '.value.worker_public_ips | length')
    WORKER_IPS=$(_jq '.value.worker_public_ips | @json')

    # Create individual access file
    cat > "$ACCESS_DIR/${PARTICIPANT}-access.txt" << ENDOFFILE
=================================================
Kubernetes Lab Access Information
=================================================

Participant: ${PARTICIPANT}
Session: ${SESSION_NAME:-Default}

Master Node: ${MASTER_IP}
  SSH: ssh ubuntu@${MASTER_IP}

Worker Nodes: ${WORKER_COUNT}
ENDOFFILE

    # Add worker IPs
    if [ "$WORKER_COUNT" -gt 0 ]; then
        echo "$WORKER_IPS" | jq -r 'to_entries[] | "  Worker-\(.key + 1): \(.value)\n    SSH: ssh ubuntu@\(.value)"' >> "$ACCESS_DIR/${PARTICIPANT}-access.txt"
    fi

    cat >> "$ACCESS_DIR/${PARTICIPANT}-access.txt" << ENDOFFILE

Getting Started:
1. Connect to your master node:
   ssh ubuntu@${MASTER_IP}

2. Verify cluster is ready:
   kubectl get nodes

   You should see ${WORKER_COUNT} worker node(s) in Ready status.

3. View detailed cluster information:
   /home/ubuntu/cluster-info.sh

4. Try deploying a test application:
   kubectl create deployment nginx --image=nginx
   kubectl expose deployment nginx --port=80 --type=NodePort
   kubectl get services

Cluster Configuration:
- Master nodes: 1
- Worker nodes: ${WORKER_COUNT}
- Kubernetes version: Check with 'kubectl version'
- Container runtime: containerd
- CNI: Calico

Useful Commands:
- View all pods: kubectl get pods --all-namespaces
- View nodes: kubectl get nodes -o wide
- View services: kubectl get services
- Cluster info: kubectl cluster-info

Support:
If you encounter any issues, please contact the instructor.

=================================================
ENDOFFILE

    echo -e "Created: ${GREEN}$ACCESS_DIR/${PARTICIPANT}-access.txt${NC}"
done

echo -e "\n${YELLOW}Access files have been created in: $ACCESS_DIR${NC}"
echo -e "${YELLOW}You can send these files to individual participants via email/Slack.${NC}\n"

# Generate a CSV for easy import into spreadsheets
CSV_FILE="$ACCESS_DIR/participants.csv"
echo "Participant,Master IP,Worker IPs,SSH Command,Worker Count,Session" > "$CSV_FILE"

echo "$CLUSTERS_JSON" | jq -r 'to_entries[] | @base64' | while read -r entry; do
    _jq() {
        echo "$entry" | base64 -d | jq -r "$1"
    }

    PARTICIPANT=$(_jq '.key')
    MASTER_IP=$(_jq '.value.master_public_ip')
    WORKER_COUNT=$(_jq '.value.worker_public_ips | length')
    WORKER_IPS_CSV=$(_jq '.value.worker_public_ips | join("; ")')
    SSH_CMD="ssh ubuntu@${MASTER_IP}"

    echo "${PARTICIPANT},${MASTER_IP},\"${WORKER_IPS_CSV}\",${SSH_CMD},${WORKER_COUNT},${SESSION_NAME:-Default}" >> "$CSV_FILE"
done

echo -e "${GREEN}CSV file created: $CSV_FILE${NC}\n"
