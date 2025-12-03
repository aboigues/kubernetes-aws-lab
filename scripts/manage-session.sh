#!/bin/bash

# Kubernetes AWS Lab - Session Management Script
# This script helps manage multiple parallel sessions with different configurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
SESSIONS_DIR="$PROJECT_ROOT/sessions"
PARTICIPANTS_DIR="$PROJECT_ROOT/participants"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Show usage
usage() {
    cat << EOF
${GREEN}Kubernetes AWS Lab - Session Management${NC}

${BLUE}Usage:${NC}
  $0 <command> <session-name> [options]

${BLUE}Commands:${NC}
  list                          List all available sessions
  workspaces                    List all Terraform workspaces
  init <session>                Initialize a new session workspace
  plan <session>                Plan infrastructure for a session
  apply <session>               Deploy infrastructure for a session
  destroy <session>             Destroy infrastructure for a session
  output <session>              Show outputs for a session
  status <session>              Show status of a session
  switch <session>              Switch to a session workspace
  create-config <session>       Create a new session configuration file

${BLUE}Examples:${NC}
  # List all sessions
  $0 list

  # Initialize and deploy session-1
  $0 init session-1
  $0 apply session-1

  # Check status of session-2
  $0 status session-2

  # Deploy multiple sessions in parallel (in separate terminals)
  Terminal 1: $0 apply session-1
  Terminal 2: $0 apply session-2

${BLUE}Session Configuration:${NC}
  - Session configs are stored in: sessions/
  - Participant SSH keys in: participants/<session-name>/
  - Each session uses a separate Terraform workspace

${BLUE}Requirements:${NC}
  - Terraform installed
  - AWS credentials configured
  - Session config file in sessions/<session-name>.tfvars
  - Participant SSH keys in participants/<session-name>/

EOF
    exit 0
}

# List all available sessions
list_sessions() {
    log_info "Available session configurations:"
    echo ""

    if [ ! -d "$SESSIONS_DIR" ] || [ -z "$(ls -A "$SESSIONS_DIR" 2>/dev/null)" ]; then
        log_warning "No session configuration files found in $SESSIONS_DIR"
        echo ""
        log_info "Create a new session config with: $0 create-config <session-name>"
        return
    fi

    for config in "$SESSIONS_DIR"/*.tfvars; do
        if [ -f "$config" ]; then
            session_name=$(basename "$config" .tfvars)

            # Extract key info from config
            worker_count=$(grep "^worker_count" "$config" | awk '{print $3}' || echo "?")
            instance_master=$(grep "^instance_type_master" "$config" | awk -F'"' '{print $2}' || echo "?")
            instance_worker=$(grep "^instance_type_worker" "$config" | awk -F'"' '{print $2}' || echo "?")

            # Check if participants directory exists
            participants_exist=""
            if [ -d "$PARTICIPANTS_DIR/$session_name" ]; then
                participant_count=$(find "$PARTICIPANTS_DIR/$session_name" -name "*.pub" 2>/dev/null | wc -l)
                participants_exist="${GREEN}${participant_count} participants${NC}"
            else
                participants_exist="${YELLOW}No participants${NC}"
            fi

            echo -e "  ${GREEN}●${NC} ${BLUE}$session_name${NC}"
            echo -e "    Config: Master ($instance_master) + $worker_count workers ($instance_worker)"
            echo -e "    Participants: $participants_exist"
            echo ""
        fi
    done
}

# List Terraform workspaces
list_workspaces() {
    cd "$TERRAFORM_DIR"
    log_info "Terraform workspaces:"
    echo ""
    terraform workspace list
}

# Initialize session workspace
init_session() {
    local session=$1

    if [ -z "$session" ]; then
        log_error "Session name required"
        echo "Usage: $0 init <session-name>"
        exit 1
    fi

    local config_file="$SESSIONS_DIR/${session}.tfvars"

    if [ ! -f "$config_file" ]; then
        log_error "Session config not found: $config_file"
        log_info "Create it with: $0 create-config $session"
        exit 1
    fi

    cd "$TERRAFORM_DIR"

    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        log_info "Initializing Terraform..."
        terraform init
    fi

    # Create or select workspace
    if terraform workspace list | grep -q "^\*\? *${session}$"; then
        log_info "Workspace '$session' already exists, selecting it..."
        terraform workspace select "$session"
    else
        log_info "Creating new workspace: $session"
        terraform workspace new "$session"
    fi

    log_success "Session '$session' initialized"
    log_info "Next steps:"
    echo "  1. Ensure SSH keys are in: participants/$session/"
    echo "  2. Review config: sessions/${session}.tfvars"
    echo "  3. Plan deployment: $0 plan $session"
    echo "  4. Apply deployment: $0 apply $session"
}

# Plan session infrastructure
plan_session() {
    local session=$1

    if [ -z "$session" ]; then
        log_error "Session name required"
        echo "Usage: $0 plan <session-name>"
        exit 1
    fi

    local config_file="$SESSIONS_DIR/${session}.tfvars"

    if [ ! -f "$config_file" ]; then
        log_error "Session config not found: $config_file"
        exit 1
    fi

    cd "$TERRAFORM_DIR"

    # Ensure workspace is selected
    if ! terraform workspace list | grep -q "^\* *${session}$"; then
        log_warning "Workspace not selected, selecting '$session'..."
        terraform workspace select "$session" || {
            log_error "Workspace '$session' not found. Run: $0 init $session"
            exit 1
        }
    fi

    log_info "Planning infrastructure for session: $session"
    terraform plan -var-file="$config_file"
}

# Apply session infrastructure
apply_session() {
    local session=$1

    if [ -z "$session" ]; then
        log_error "Session name required"
        echo "Usage: $0 apply <session-name>"
        exit 1
    fi

    local config_file="$SESSIONS_DIR/${session}.tfvars"

    if [ ! -f "$config_file" ]; then
        log_error "Session config not found: $config_file"
        exit 1
    fi

    # Check for participant SSH keys
    if [ ! -d "$PARTICIPANTS_DIR/$session" ] || [ -z "$(find "$PARTICIPANTS_DIR/$session" -name "*.pub" 2>/dev/null)" ]; then
        log_error "No participant SSH keys found in: $PARTICIPANTS_DIR/$session"
        log_info "Add at least one .pub file to proceed"
        exit 1
    fi

    cd "$TERRAFORM_DIR"

    # Ensure workspace is selected
    if ! terraform workspace list | grep -q "^\* *${session}$"; then
        log_warning "Workspace not selected, selecting '$session'..."
        terraform workspace select "$session" || {
            log_error "Workspace '$session' not found. Run: $0 init $session"
            exit 1
        }
    fi

    log_info "Deploying infrastructure for session: $session"
    terraform apply -var-file="$config_file"
}

# Destroy session infrastructure
destroy_session() {
    local session=$1

    if [ -z "$session" ]; then
        log_error "Session name required"
        echo "Usage: $0 destroy <session-name>"
        exit 1
    fi

    local config_file="$SESSIONS_DIR/${session}.tfvars"

    if [ ! -f "$config_file" ]; then
        log_error "Session config not found: $config_file"
        exit 1
    fi

    cd "$TERRAFORM_DIR"

    # Ensure workspace is selected
    if ! terraform workspace list | grep -q "^\* *${session}$"; then
        log_warning "Workspace not selected, selecting '$session'..."
        terraform workspace select "$session" || {
            log_error "Workspace '$session' not found"
            exit 1
        }
    fi

    log_warning "Destroying infrastructure for session: $session"
    terraform destroy -var-file="$config_file"
}

# Show session output
output_session() {
    local session=$1

    if [ -z "$session" ]; then
        log_error "Session name required"
        echo "Usage: $0 output <session-name>"
        exit 1
    fi

    cd "$TERRAFORM_DIR"

    # Ensure workspace is selected
    if ! terraform workspace list | grep -q "^\* *${session}$"; then
        terraform workspace select "$session" || {
            log_error "Workspace '$session' not found"
            exit 1
        }
    fi

    log_info "Outputs for session: $session"
    terraform output
}

# Show session status
status_session() {
    local session=$1

    if [ -z "$session" ]; then
        log_error "Session name required"
        echo "Usage: $0 status <session-name>"
        exit 1
    fi

    local config_file="$SESSIONS_DIR/${session}.tfvars"

    echo ""
    log_info "Status for session: ${BLUE}$session${NC}"
    echo ""

    # Check config file
    if [ -f "$config_file" ]; then
        log_success "Config file exists: sessions/${session}.tfvars"

        # Show config details
        worker_count=$(grep "^worker_count" "$config_file" | awk '{print $3}' || echo "?")
        instance_master=$(grep "^instance_type_master" "$config_file" | awk -F'"' '{print $2}' || echo "?")
        instance_worker=$(grep "^instance_type_worker" "$config_file" | awk -F'"' '{print $2}' || echo "?")

        echo "  - Workers: $worker_count"
        echo "  - Master type: $instance_master"
        echo "  - Worker type: $instance_worker"
    else
        log_error "Config file not found: sessions/${session}.tfvars"
    fi

    echo ""

    # Check participants
    if [ -d "$PARTICIPANTS_DIR/$session" ]; then
        participant_count=$(find "$PARTICIPANTS_DIR/$session" -name "*.pub" 2>/dev/null | wc -l)
        if [ "$participant_count" -gt 0 ]; then
            log_success "Participants directory exists with $participant_count SSH key(s)"
        else
            log_warning "Participants directory exists but no SSH keys found"
        fi
    else
        log_warning "Participants directory not found: participants/$session"
    fi

    echo ""

    # Check workspace
    cd "$TERRAFORM_DIR"
    if terraform workspace list 2>/dev/null | grep -q "^\*\? *${session}$"; then
        log_success "Terraform workspace exists"

        # Check if infrastructure is deployed
        if [ -f "terraform.tfstate.d/$session/terraform.tfstate" ] || [ -f "terraform.tfstate" ]; then
            log_info "Checking deployment status..."
            terraform workspace select "$session" &>/dev/null

            # Get resource count
            resource_count=$(terraform state list 2>/dev/null | wc -l || echo "0")
            if [ "$resource_count" -gt 0 ]; then
                log_success "Infrastructure deployed ($resource_count resources)"
            else
                log_warning "Workspace exists but no resources deployed"
            fi
        fi
    else
        log_warning "Terraform workspace not initialized"
        echo "  Run: $0 init $session"
    fi

    echo ""
}

# Switch to session workspace
switch_session() {
    local session=$1

    if [ -z "$session" ]; then
        log_error "Session name required"
        echo "Usage: $0 switch <session-name>"
        exit 1
    fi

    cd "$TERRAFORM_DIR"

    if terraform workspace list | grep -q "^\*\? *${session}$"; then
        terraform workspace select "$session"
        log_success "Switched to workspace: $session"
    else
        log_error "Workspace '$session' not found"
        log_info "Initialize it with: $0 init $session"
        exit 1
    fi
}

# Create new session config
create_config() {
    local session=$1

    if [ -z "$session" ]; then
        log_error "Session name required"
        echo "Usage: $0 create-config <session-name>"
        exit 1
    fi

    local config_file="$SESSIONS_DIR/${session}.tfvars"

    if [ -f "$config_file" ]; then
        log_error "Session config already exists: $config_file"
        exit 1
    fi

    # Create sessions directory if it doesn't exist
    mkdir -p "$SESSIONS_DIR"

    # Create config file from template
    cat > "$config_file" << EOF
# Session $session Configuration

# AWS Region
aws_region = "eu-west-1"

# Session Configuration (IMPORTANT for cost tracking and workspace naming)
session_name = "$session"

# VPC Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"]

# Security Configuration
allowed_ssh_cidrs = ["0.0.0.0/0"]
allowed_api_cidrs = ["0.0.0.0/0"]

# EC2 Instance Types
instance_type_master = "t3.medium"  # 2 vCPU, 4 GB RAM
instance_type_worker = "t3.small"   # 2 vCPU, 2 GB RAM

# Cluster Configuration
worker_count       = 2  # Number of worker nodes per cluster
kubernetes_version = "1.28"

# Project Name
project_name = "k8s-lab"
EOF

    log_success "Created session config: $config_file"
    log_info "Next steps:"
    echo "  1. Edit the config file to customize: sessions/${session}.tfvars"
    echo "  2. Create participants directory: mkdir -p participants/$session"
    echo "  3. Add SSH keys: participants/$session/*.pub"
    echo "  4. Initialize session: $0 init $session"
}

# Main script
main() {
    local command=$1
    shift || true

    case "$command" in
        list)
            list_sessions
            ;;
        workspaces)
            list_workspaces
            ;;
        init)
            init_session "$@"
            ;;
        plan)
            plan_session "$@"
            ;;
        apply)
            apply_session "$@"
            ;;
        destroy)
            destroy_session "$@"
            ;;
        output)
            output_session "$@"
            ;;
        status)
            status_session "$@"
            ;;
        switch)
            switch_session "$@"
            ;;
        create-config)
            create_config "$@"
            ;;
        help|--help|-h|"")
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            usage
            ;;
    esac
}

main "$@"
