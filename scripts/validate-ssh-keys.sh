#!/bin/bash

# Script to validate SSH keys for multi-session deployments
# This script works with Terraform workspaces to support parallel sessions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
SESSIONS_DIR="$PROJECT_ROOT/sessions"
PARTICIPANTS_DIR="$PROJECT_ROOT/participants"

# Colors for output
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m' # No Color

# Counters
total=0
valid=0
invalid=0

# Show usage
usage() {
    cat << EOF
${GREEN}Kubernetes AWS Lab - SSH Keys Validation${NC}

${BLUE}Usage:${NC}
  $0                          Validate all sessions
  $0 <session-name>           Validate keys for a specific session
  $0 <file.pub>               Validate a specific key file
  $0 <directory>              Validate all keys in a directory

${BLUE}Description:${NC}
  Validates SSH public keys for multi-session deployments.
  Checks filename format, content format, and key validity.

${BLUE}Examples:${NC}
  # Validate all sessions
  $0

  # Validate keys for session-1
  $0 session-1

  # Validate a specific file
  $0 participants/session-1/john.doe.pub

  # Validate all keys in a directory
  $0 participants/session-1

${BLUE}Key Requirements:${NC}
  - Filename format: prenom.nom.pub (e.g., john.doe.pub)
  - Key type: ssh-ed25519
  - Single line per file
  - Valid base64 encoding

${BLUE}Multi-Session Structure:${NC}
  participants/
  ├── session-1/
  │   ├── john.doe.pub
  │   └── jane.smith.pub
  └── session-2/
      └── alice.jones.pub

EOF
    exit 0
}

validate_key_file() {
    local file=$1
    local filename=$(basename "$file")

    # Skip README and hidden files
    if [[ "$filename" == "README.md" ]] || [[ "$filename" == .* ]]; then
        return 0
    fi

    ((total++))

    # Check filename format
    if [[ "$filename" =~ ^[a-z]+\.[a-z]+\.pub$ ]]; then
        : # filename is valid
    else
        echo -e "${RED}✗${NC} $filename: Invalid filename format (expected: prenom.nom.pub)"
        ((invalid++))
        return 1
    fi

    # Check file is not empty
    if [[ ! -s "$file" ]]; then
        echo -e "${RED}✗${NC} $filename: File is empty"
        ((invalid++))
        return 1
    fi

    # Check number of lines (wc -l counts newlines, so a single line without trailing newline = 0)
    local lines=$(wc -l < "$file")
    local actual_lines=$(grep -c . "$file" || echo "0")
    if [[ $actual_lines -ne 1 ]]; then
        echo -e "${RED}✗${NC} $filename: File should contain exactly one line (found: $actual_lines)"
        ((invalid++))
        return 1
    fi

    # Read the key
    local key=$(cat "$file")

    # Check if it starts with ssh-ed25519
    if [[ "$key" =~ ^ssh-ed25519[[:space:]] ]]; then
        : # key format is valid
    else
        echo -e "${RED}✗${NC} $filename: Key must start with 'ssh-ed25519' (found: $(echo "$key" | cut -d' ' -f1))"
        ((invalid++))
        return 1
    fi

    # Validate key format (ed25519 keys are 68 characters in base64)
    local key_part=$(echo "$key" | awk '{print $2}')
    local key_length=${#key_part}

    # ed25519 public keys should be around 68 characters in base64
    if [[ $key_length -lt 60 || $key_length -gt 80 ]]; then
        echo -e "${YELLOW}⚠${NC} $filename: Key length unusual ($key_length chars, expected ~68)"
    fi

    # Check if key_part is valid base64
    if echo "$key_part" | grep -qE '^[A-Za-z0-9+/]+=*$'; then
        # Try to validate with ssh-keygen if available
        if command -v ssh-keygen &>/dev/null; then
            if echo "$key" | ssh-keygen -l -f - &>/dev/null; then
                local fingerprint=$(echo "$key" | ssh-keygen -l -f - | awk '{print $2}')
                echo -e "${GREEN}✓${NC} $filename: Valid (fingerprint: $fingerprint)"
            else
                echo -e "${RED}✗${NC} $filename: Invalid key format (ssh-keygen validation failed)"
                ((invalid++))
                return 1
            fi
        else
            # Fallback: basic format validation only
            echo -e "${GREEN}✓${NC} $filename: Format appears valid (length: $key_length)"
        fi
        ((valid++))
        return 0
    else
        echo -e "${RED}✗${NC} $filename: Key contains invalid base64 characters"
        ((invalid++))
        return 1
    fi
}

# Check for help flag
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}SSH Keys Validation${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Determine what to validate based on arguments
if [[ $# -eq 0 ]]; then
    # No arguments: validate all sessions
    if [[ ! -d "$PARTICIPANTS_DIR" ]]; then
        echo -e "${RED}Error:${NC} Participants directory not found: $PARTICIPANTS_DIR"
        exit 1
    fi

    # Find all session directories
    session_dirs=$(find "$PARTICIPANTS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

    if [[ -z "$session_dirs" ]]; then
        echo -e "${YELLOW}No session directories found in $PARTICIPANTS_DIR${NC}"
        echo ""
        echo "Create a session directory structure:"
        echo "  mkdir -p participants/<session-name>"
        echo "  cp your-key.pub participants/<session-name>/"
        exit 0
    fi

    echo -e "${BLUE}Validating all sessions in: ${NC}$PARTICIPANTS_DIR"
    echo ""

    # Validate each session
    while IFS= read -r session_dir; do
        session_name=$(basename "$session_dir")

        # Count keys in this session
        key_count=$(find "$session_dir" -maxdepth 1 -type f -name "*.pub" 2>/dev/null | wc -l)

        if [[ $key_count -eq 0 ]]; then
            echo -e "${YELLOW}Session: $session_name${NC}"
            echo -e "  ${YELLOW}⚠${NC} No SSH keys found"
            echo ""
            continue
        fi

        echo -e "${BLUE}Session: $session_name${NC} ($key_count key(s))"
        echo ""

        # Validate all keys in this session
        while IFS= read -r -d '' file; do
            validate_key_file "$file"
        done < <(find "$session_dir" -maxdepth 1 -type f -name "*.pub" -print0 | sort -z)

        echo ""
    done <<< "$session_dirs"

elif [[ $# -eq 1 ]]; then
    arg="$1"

    # Check if it's a session name
    if [[ -d "$PARTICIPANTS_DIR/$arg" ]]; then
        # Session directory validation
        session_dir="$PARTICIPANTS_DIR/$arg"

        echo -e "${BLUE}Validating session: ${NC}$arg"
        echo ""

        # Count keys
        key_count=$(find "$session_dir" -maxdepth 1 -type f -name "*.pub" 2>/dev/null | wc -l)

        if [[ $key_count -eq 0 ]]; then
            echo -e "${YELLOW}No SSH keys found in session directory${NC}"
            echo -e "Add keys to: $session_dir"
            exit 0
        fi

        echo -e "Found $key_count key(s)"
        echo ""

        # Validate all keys in this session
        while IFS= read -r -d '' file; do
            validate_key_file "$file"
        done < <(find "$session_dir" -maxdepth 1 -type f -name "*.pub" -print0 | sort -z)

    elif [[ -f "$arg" ]]; then
        # Single file validation
        echo -e "${BLUE}Validating file: ${NC}$arg"
        echo ""
        validate_key_file "$arg"

    elif [[ -d "$arg" ]]; then
        # Generic directory validation
        echo -e "${BLUE}Validating directory: ${NC}$arg"
        echo ""

        # Find all .pub files in the specified directory (maxdepth 1)
        key_count=$(find "$arg" -maxdepth 1 -type f -name "*.pub" 2>/dev/null | wc -l)

        if [[ $key_count -eq 0 ]]; then
            echo -e "${YELLOW}No .pub files found in directory${NC}"
            exit 0
        fi

        echo -e "Found $key_count key(s)"
        echo ""

        while IFS= read -r -d '' file; do
            validate_key_file "$file"
        done < <(find "$arg" -maxdepth 1 -type f -name "*.pub" -print0 | sort -z)

    else
        echo -e "${RED}Error:${NC} Session, file, or directory not found: $arg"
        echo ""
        echo -e "${YELLOW}Available sessions:${NC}"
        if [[ -d "$PARTICIPANTS_DIR" ]]; then
            ls -1 "$PARTICIPANTS_DIR" 2>/dev/null | sed 's/^/  - /' || echo "  (none)"
        else
            echo "  (participants directory not found)"
        fi
        exit 1
    fi
else
    echo -e "${RED}Error:${NC} Too many arguments"
    echo ""
    usage
fi

echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo "Total keys: $total"
echo -e "${GREEN}Valid: $valid${NC}"
if [[ $invalid -gt 0 ]]; then
    echo -e "${RED}Invalid: $invalid${NC}"
fi
echo ""

if [[ $invalid -gt 0 ]]; then
    echo -e "${RED}✗ Validation failed!${NC} Please fix the errors above."
    exit 1
else
    echo -e "${GREEN}✓ All keys are valid!${NC}"
    exit 0
fi
