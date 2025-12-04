#!/bin/bash

# Script to start the Kubernetes AWS Lab Web Dashboard
# This dashboard displays real-time participant access information

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
DASHBOARD_DIR="$SCRIPT_DIR/web-dashboard"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Show usage
usage() {
    cat << EOF
${GREEN}Kubernetes AWS Lab - Web Dashboard${NC}

${BLUE}Usage:${NC}
  $0 [options]

${BLUE}Options:${NC}
  -p, --port PORT      Port to run the server on (default: 8080)
  -h, --help          Show this help message

${BLUE}Description:${NC}
  Starts a web dashboard that displays participant access information
  in real-time. The dashboard automatically refreshes every 10 seconds.

${BLUE}Features:${NC}
  - Real-time participant information display
  - Automatic data refresh
  - Copy SSH commands with one click
  - Responsive design for mobile and desktop
  - Support for multiple sessions

${BLUE}Examples:${NC}
  # Start dashboard on default port (8080)
  $0

  # Start on custom port
  $0 --port 3000

${BLUE}Access:${NC}
  Once started, open your browser to:
  http://localhost:8080

${BLUE}Requirements:${NC}
  - Python 3.6 or higher
  - Flask (will be installed if missing)
  - Terraform with deployed session
  - jq for JSON parsing

EOF
    exit 0
}

# Default values
PORT=8080

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

echo -e "${BLUE}=== Kubernetes AWS Lab - Web Dashboard ===${NC}\n"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    echo -e "${YELLOW}Please install Python 3.6 or higher${NC}"
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
echo -e "${GREEN}✓${NC} Python version: ${PYTHON_VERSION}"

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}Error: pip3 is not installed${NC}"
    echo -e "${YELLOW}Please install pip3${NC}"
    exit 1
fi

# Check if Flask is installed, if not, offer to install
if ! python3 -c "import flask" 2>/dev/null; then
    echo -e "${YELLOW}Flask is not installed.${NC}"
    echo -e "${BLUE}Installing Flask...${NC}"

    if pip3 install flask --user; then
        echo -e "${GREEN}✓${NC} Flask installed successfully"
    else
        echo -e "${RED}Error: Failed to install Flask${NC}"
        echo -e "${YELLOW}Please install Flask manually:${NC}"
        echo -e "  pip3 install flask"
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} Flask is installed"
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${YELLOW}Warning: Terraform is not installed or not in PATH${NC}"
    echo -e "${YELLOW}The dashboard will not be able to fetch data without Terraform${NC}"
else
    echo -e "${GREEN}✓${NC} Terraform is available"
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq is not installed${NC}"
    echo -e "${YELLOW}jq is recommended for better JSON parsing${NC}"
else
    echo -e "${GREEN}✓${NC} jq is available"
fi

# Check if terraform directory exists
if [ ! -d "$PROJECT_ROOT/terraform" ]; then
    echo -e "${YELLOW}Warning: Terraform directory not found${NC}"
    echo -e "${YELLOW}Expected location: $PROJECT_ROOT/terraform${NC}"
fi

# Change to dashboard directory
cd "$DASHBOARD_DIR"

echo -e "\n${BLUE}=== Starting Dashboard ===${NC}\n"
echo -e "Dashboard URL: ${GREEN}http://localhost:${PORT}${NC}"
echo -e "Press ${YELLOW}CTRL+C${NC} to stop the server\n"
echo -e "${BLUE}───────────────────────────────────────────────────${NC}\n"

# Start the Flask application
export FLASK_APP=app.py
export FLASK_ENV=development

# Run with custom port
python3 app.py 2>&1 | sed "s/8080/$PORT/g" || {
    echo -e "\n${RED}Error: Failed to start the dashboard${NC}"
    exit 1
}
