#!/bin/bash
set -euo pipefail

# Session Start Hook for Kubernetes AWS Lab
# Purpose: Remind Claude to read PROJECT-RULES.md before any work

# Output reminder message
cat << 'EOF'

╔════════════════════════════════════════════════════════════════════════════╗
║                    🔔 PROJECT RULES REMINDER 🔔                            ║
╠════════════════════════════════════════════════════════════════════════════╣
║                                                                            ║
║  IMPORTANT: Before working on this project, you MUST read:                ║
║                                                                            ║
║    📋 docs/PROJECT-RULES.md                                               ║
║                                                                            ║
║  This document contains all mandatory conventions, standards, and rules.  ║
║                                                                            ║
║  Quick command: /read-project-rules                                       ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝

EOF

# Create a reminder file that Claude can see
cat > "$CLAUDE_PROJECT_DIR/.RULES-REMINDER.txt" << 'EOF'
⚠️  MANDATORY: READ PROJECT RULES BEFORE ANY WORK ⚠️

Location: docs/PROJECT-RULES.md

This file contains ALL project conventions including:
- Naming conventions (SSH keys: prenom.nom.pub, sessions, AWS resources)
- Code standards (Bash, Terraform, Python)
- Terraform rules (8 core variables, modules, patterns)
- Session management (lifecycle, workspaces, parallel sessions)
- Participant management (ed25519 keys, validation, name transformation)
- Network architecture (VPC, subnets, Kubernetes networking)
- Security rules (security groups, best practices)
- Deployment processes (workflow, validation, testing)
- Cost management (tagging, calculations, AWS pricing)
- Dashboard configuration
- Documentation standards
- Git conventions
- Best practices (before/during/after sessions)
- Technology stack

Use command: /read-project-rules
EOF

echo "✅ Session start hook completed - PROJECT-RULES.md reminder displayed"
