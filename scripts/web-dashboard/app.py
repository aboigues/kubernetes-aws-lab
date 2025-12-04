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
                'participants': []
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

        return {
            'session': current_session,
            'timestamp': datetime.now().isoformat(),
            'participant_count': len(participants),
            'participants': participants
        }

    except subprocess.TimeoutExpired:
        return {
            'error': 'Terraform command timed out',
            'session': current_session if 'current_session' in locals() else None,
            'participants': []
        }
    except json.JSONDecodeError:
        return {
            'error': 'Invalid JSON from Terraform output',
            'session': current_session if 'current_session' in locals() else None,
            'participants': []
        }
    except Exception as e:
        return {
            'error': f'Unexpected error: {str(e)}',
            'session': current_session if 'current_session' in locals() else None,
            'participants': []
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
