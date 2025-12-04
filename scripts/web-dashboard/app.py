#!/usr/bin/env python3
"""
Kubernetes AWS Lab - Web Dashboard
Real-time participant access information display
"""

import os
import json
import subprocess
from flask import Flask, render_template, jsonify
from datetime import datetime

app = Flask(__name__)

# AWS Pricing (eu-west-1 region, prices in USD per hour)
# Source: AWS Pricing Calculator - December 2025
AWS_PRICING = {
    'ec2': {
        't3.nano': 0.0052,
        't3.micro': 0.0104,
        't3.small': 0.0208,
        't3.medium': 0.0416,
        't3.large': 0.0832,
        't3.xlarge': 0.1664,
        't3.2xlarge': 0.3328,
        't2.micro': 0.0126,
        't2.small': 0.023,
        't2.medium': 0.0464,
        't2.large': 0.0928,
    },
    'nat_gateway': 0.045,  # per NAT Gateway per hour
    'ebs_gp3': 0.088 / 730,  # $0.088 per GB-month -> per hour (730 hours/month average)
}

# Path configuration
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "../.."))
TERRAFORM_DIR = os.path.join(PROJECT_ROOT, "terraform")
SESSIONS_DIR = os.path.join(PROJECT_ROOT, "sessions")


def get_available_sessions():
    """Get list of available sessions from sessions directory"""
    if not os.path.exists(SESSIONS_DIR):
        return []

    sessions = []
    for file in os.listdir(SESSIONS_DIR):
        if file.endswith('.tfvars'):
            sessions.append(file.replace('.tfvars', ''))
    return sorted(sessions)


def get_current_workspace():
    """Get current Terraform workspace"""
    try:
        result = subprocess.run(
            ['terraform', 'workspace', 'show'],
            cwd=TERRAFORM_DIR,
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception as e:
        print(f"Error getting workspace: {e}")
    return None


def get_terraform_variables():
    """
    Get Terraform variables (instance types, worker count, etc.)

    Returns:
        dict: Terraform variables including instance types and counts
    """
    try:
        original_dir = os.getcwd()
        os.chdir(TERRAFORM_DIR)

        # Get instance_type_master variable
        result_master = subprocess.run(
            ['terraform', 'output', '-json', 'instance_type_master'],
            capture_output=True,
            text=True,
            timeout=5
        )

        # Get instance_type_worker variable
        result_worker = subprocess.run(
            ['terraform', 'output', '-json', 'instance_type_worker'],
            capture_output=True,
            text=True,
            timeout=5
        )

        # Get worker_count variable
        result_count = subprocess.run(
            ['terraform', 'output', '-json', 'worker_count'],
            capture_output=True,
            text=True,
            timeout=5
        )

        # Get availability_zones to count NAT gateways
        result_azs = subprocess.run(
            ['terraform', 'output', '-json', 'availability_zones'],
            capture_output=True,
            text=True,
            timeout=5
        )

        os.chdir(original_dir)

        instance_type_master = 't3.medium'  # default
        instance_type_worker = 't3.small'   # default
        worker_count = 2                    # default
        nat_gateway_count = 2               # default (2 AZs)

        if result_master.returncode == 0:
            instance_type_master = json.loads(result_master.stdout)
        if result_worker.returncode == 0:
            instance_type_worker = json.loads(result_worker.stdout)
        if result_count.returncode == 0:
            worker_count = json.loads(result_count.stdout)
        if result_azs.returncode == 0:
            azs = json.loads(result_azs.stdout)
            nat_gateway_count = len(azs)

        return {
            'instance_type_master': instance_type_master,
            'instance_type_worker': instance_type_worker,
            'worker_count': worker_count,
            'nat_gateway_count': nat_gateway_count
        }

    except Exception as e:
        print(f"Error getting Terraform variables: {e}")
        # Return defaults
        return {
            'instance_type_master': 't3.medium',
            'instance_type_worker': 't3.small',
            'worker_count': 2,
            'nat_gateway_count': 2
        }


def calculate_hourly_cost(participant_count, tf_vars):
    """
    Calculate total hourly cost of AWS infrastructure

    Args:
        participant_count: Number of participants (K8s clusters)
        tf_vars: Terraform variables dict with instance types and counts

    Returns:
        float: Total hourly cost in USD
    """
    total_cost = 0.0

    # EC2 Instances
    master_type = tf_vars.get('instance_type_master', 't3.medium')
    worker_type = tf_vars.get('instance_type_worker', 't3.small')
    worker_count = tf_vars.get('worker_count', 2)

    # Cost per participant cluster
    master_cost = AWS_PRICING['ec2'].get(master_type, 0.0416)  # default to t3.medium
    worker_cost = AWS_PRICING['ec2'].get(worker_type, 0.0208)  # default to t3.small

    ec2_cost_per_cluster = master_cost + (worker_cost * worker_count)
    total_ec2_cost = ec2_cost_per_cluster * participant_count

    # EBS Volumes
    # Master: 30GB, Workers: 20GB each
    master_volume_gb = 30
    worker_volume_gb = 20
    total_storage_gb = participant_count * (master_volume_gb + (worker_volume_gb * worker_count))
    ebs_cost = total_storage_gb * AWS_PRICING['ebs_gp3']

    # NAT Gateways (shared across all clusters)
    nat_gateway_count = tf_vars.get('nat_gateway_count', 2)
    nat_cost = nat_gateway_count * AWS_PRICING['nat_gateway']

    # Total
    total_cost = total_ec2_cost + ebs_cost + nat_cost

    return {
        'total_hourly': total_cost,
        'ec2': total_ec2_cost,
        'ebs': ebs_cost,
        'nat_gateway': nat_cost,
        'breakdown': {
            'master_instance_type': master_type,
            'master_hourly_cost': master_cost,
            'worker_instance_type': worker_type,
            'worker_hourly_cost': worker_cost,
            'worker_count_per_cluster': worker_count,
            'clusters': participant_count,
            'nat_gateways': nat_gateway_count
        }
    }


def get_session_data(session_name=None):
    """
    Get participant access information from Terraform output

    Args:
        session_name: Optional session name. If None, uses current workspace

    Returns:
        dict: Session data including participants info
    """
    try:
        # Change to terraform directory
        original_dir = os.getcwd()
        os.chdir(TERRAFORM_DIR)

        # If session_name provided, switch workspace
        if session_name:
            subprocess.run(
                ['terraform', 'workspace', 'select', session_name],
                capture_output=True,
                text=True,
                timeout=5
            )

        # Get current workspace
        current_session = get_current_workspace()

        # Get clusters output
        result = subprocess.run(
            ['terraform', 'output', '-json', 'clusters'],
            capture_output=True,
            text=True,
            timeout=10
        )

        os.chdir(original_dir)

        if result.returncode != 0:
            return {
                'error': 'Failed to get Terraform output',
                'session': current_session,
                'participants': [],
                'cost': {'total_hourly': 0, 'ec2': 0, 'ebs': 0, 'nat_gateway': 0}
            }

        clusters = json.loads(result.stdout)

        # Transform data for easier consumption
        participants = []
        for participant_name, cluster_info in clusters.items():
            participants.append({
                'name': participant_name,
                'master_ip': cluster_info.get('master_public_ip', 'N/A'),
                'master_private_ip': cluster_info.get('master_private_ip', 'N/A'),
                'worker_count': len(cluster_info.get('worker_public_ips', [])),
                'worker_public_ips': cluster_info.get('worker_public_ips', []),
                'worker_private_ips': cluster_info.get('worker_private_ips', []),
                'ssh_command': f"ssh ubuntu@{cluster_info.get('master_public_ip', 'N/A')}"
            })

        # Get Terraform variables for cost calculation
        tf_vars = get_terraform_variables()

        # Calculate costs
        cost_info = calculate_hourly_cost(len(participants), tf_vars)

        return {
            'session': current_session,
            'timestamp': datetime.now().isoformat(),
            'participant_count': len(participants),
            'participants': participants,
            'cost': cost_info
        }

    except subprocess.TimeoutExpired:
        return {
            'error': 'Terraform command timed out',
            'session': current_session if 'current_session' in locals() else None,
            'participants': [],
            'cost': {'total_hourly': 0, 'ec2': 0, 'ebs': 0, 'nat_gateway': 0}
        }
    except json.JSONDecodeError:
        return {
            'error': 'Invalid JSON from Terraform output',
            'session': current_session if 'current_session' in locals() else None,
            'participants': [],
            'cost': {'total_hourly': 0, 'ec2': 0, 'ebs': 0, 'nat_gateway': 0}
        }
    except Exception as e:
        return {
            'error': f'Unexpected error: {str(e)}',
            'session': current_session if 'current_session' in locals() else None,
            'participants': [],
            'cost': {'total_hourly': 0, 'ec2': 0, 'ebs': 0, 'nat_gateway': 0}
        }


@app.route('/')
def index():
    """Render main dashboard page"""
    sessions = get_available_sessions()
    current_session = get_current_workspace()
    return render_template('dashboard.html',
                         sessions=sessions,
                         current_session=current_session)


@app.route('/api/data')
def api_data():
    """API endpoint to get participant data"""
    data = get_session_data()
    return jsonify(data)


@app.route('/api/data/<session_name>')
def api_data_session(session_name):
    """API endpoint to get data for specific session"""
    data = get_session_data(session_name)
    return jsonify(data)


@app.route('/api/sessions')
def api_sessions():
    """API endpoint to get available sessions"""
    sessions = get_available_sessions()
    current = get_current_workspace()
    return jsonify({
        'sessions': sessions,
        'current': current
    })


@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'timestamp': datetime.now().isoformat()})


@app.route('/api/cost')
def api_cost():
    """API endpoint to get cost information"""
    try:
        data = get_session_data()
        if 'cost' in data:
            return jsonify({
                'cost': data['cost'],
                'timestamp': datetime.now().isoformat()
            })
        return jsonify({'error': 'Cost data not available'}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    print("=" * 60)
    print("Kubernetes AWS Lab - Web Dashboard")
    print("=" * 60)
    print(f"Project Root: {PROJECT_ROOT}")
    print(f"Terraform Dir: {TERRAFORM_DIR}")
    print(f"Available Sessions: {', '.join(get_available_sessions())}")
    print(f"Current Workspace: {get_current_workspace()}")
    print("=" * 60)
    print("\nStarting server on http://0.0.0.0:8080")
    print("Press CTRL+C to stop\n")

    app.run(host='0.0.0.0', port=8080, debug=True)
