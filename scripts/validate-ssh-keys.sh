#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
total=0
valid=0
invalid=0

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

echo "================================"
echo "SSH Keys Validation"
echo "================================"
echo ""

# If a specific file is provided, validate only that file
if [[ $# -eq 1 ]]; then
    if [[ -f "$1" ]]; then
        validate_key_file "$1"
    else
        echo -e "${RED}Error:${NC} File not found: $1"
        exit 1
    fi
else
    # Validate all .pub files in participants directory
    participants_dir="participants"

    if [[ ! -d "$participants_dir" ]]; then
        echo -e "${RED}Error:${NC} Directory '$participants_dir' not found"
        exit 1
    fi

    # Find all .pub files
    while IFS= read -r -d '' file; do
        validate_key_file "$file"
    done < <(find "$participants_dir" -maxdepth 1 -type f -name "*.pub" -print0 | sort -z)
fi

echo ""
echo "================================"
echo "Summary"
echo "================================"
echo "Total keys: $total"
echo -e "${GREEN}Valid: $valid${NC}"
if [[ $invalid -gt 0 ]]; then
    echo -e "${RED}Invalid: $invalid${NC}"
fi
echo ""

if [[ $invalid -gt 0 ]]; then
    echo -e "${RED}Validation failed!${NC} Please fix the errors above."
    exit 1
else
    echo -e "${GREEN}All keys are valid!${NC}"
    exit 0
fi
