# Session Configurations

This directory contains configuration files for different Kubernetes lab sessions. Each session can have its own configuration (number of workers, instance types, etc.) and can run in parallel with other sessions.

## Session Configuration Files

Each `.tfvars` file in this directory defines a complete session configuration:

- **session-1.tfvars**: Simple setup with 1 master only (no workers)
- **session-2.tfvars**: Standard setup with 1 master + 2 workers
- **session-3.tfvars**: Large setup with 1 master + 5 workers

## File Format

Each session configuration file should include:

```hcl
# Session name (must match the filename)
session_name = "session-1"

# AWS Configuration
aws_region = "eu-west-1"
availability_zones = ["eu-west-1a", "eu-west-1b"]

# Instance Types
instance_type_master = "t3.medium"
instance_type_worker = "t3.small"

# Cluster Configuration
worker_count = 2
kubernetes_version = "1.28"

# Security
allowed_ssh_cidrs = ["0.0.0.0/0"]
allowed_api_cidrs = ["0.0.0.0/0"]

# VPC
vpc_cidr = "10.0.0.0/16"
project_name = "k8s-lab"
```

## Creating a New Session

### Option 1: Using the Management Script

```bash
# Create a new session configuration
./scripts/manage-session.sh create-config my-session

# Edit the configuration
vi sessions/my-session.tfvars

# Create participant directory and add SSH keys
mkdir -p participants/my-session
cp ~/.ssh/id_rsa.pub participants/my-session/john.doe.pub
```

### Option 2: Manual Creation

1. Copy an existing session file:
   ```bash
   cp sessions/session-1.tfvars sessions/my-session.tfvars
   ```

2. Edit the configuration:
   ```bash
   vi sessions/my-session.tfvars
   ```

3. Update the `session_name` to match your filename

4. Create participant directory and add SSH keys:
   ```bash
   mkdir -p participants/my-session
   ```

## Participant SSH Keys

For each session, you need to create a corresponding directory in `participants/` with the same name:

```
participants/
├── session-1/
│   ├── alice.smith.pub
│   └── bob.jones.pub
├── session-2/
│   ├── charlie.brown.pub
│   └── diana.prince.pub
└── session-3/
    └── eve.wilson.pub
```

The session name in the configuration file must match the directory name in `participants/`.

## Session Configuration Options

### Instance Types

Choose based on your workload:

| Type | vCPU | Memory | Use Case |
|------|------|--------|----------|
| t3.micro | 2 | 1 GB | Testing only |
| t3.small | 2 | 2 GB | Light workers |
| t3.medium | 2 | 4 GB | Standard master/workers |
| t3.large | 2 | 8 GB | Heavy workloads |
| t3.xlarge | 4 | 16 GB | Large clusters |

### Worker Count

- `worker_count = 0`: Master-only setup (good for testing)
- `worker_count = 1-2`: Small cluster (typical for labs)
- `worker_count = 3-5`: Medium cluster (production-like)
- `worker_count = 6+`: Large cluster (requires larger master instance)

### Security Configuration

For production or restricted environments:

```hcl
# Allow SSH only from office IP
allowed_ssh_cidrs = ["203.0.113.0/24"]

# Allow K8s API only from VPN
allowed_api_cidrs = ["198.51.100.0/24"]
```

For lab/testing (default):

```hcl
# Allow from anywhere
allowed_ssh_cidrs = ["0.0.0.0/0"]
allowed_api_cidrs = ["0.0.0.0/0"]
```

## Parallel Sessions

Multiple sessions can run simultaneously. Each session:

- Has its own Terraform workspace
- Has its own infrastructure state
- Has its own cost tracking tags
- Shares the same VPC (cost optimization)
- Has isolated security groups per participant

### Example: Running 3 Sessions in Parallel

**Terminal 1:**
```bash
./scripts/manage-session.sh init session-1
./scripts/manage-session.sh apply session-1
```

**Terminal 2:**
```bash
./scripts/manage-session.sh init session-2
./scripts/manage-session.sh apply session-2
```

**Terminal 3:**
```bash
./scripts/manage-session.sh init session-3
./scripts/manage-session.sh apply session-3
```

All three sessions will deploy simultaneously without conflicts.

## Managing Sessions

See the [Session Management Guide](../docs/PARALLEL-SESSIONS.md) for detailed instructions on:

- Initializing sessions
- Deploying infrastructure
- Managing multiple sessions
- Cost tracking per session
- Troubleshooting

## Best Practices

1. **Naming**: Use descriptive session names (e.g., `training-nov-2025`, `team-alpha`)
2. **Consistency**: Keep `session_name` in tfvars matching the filename
3. **Participants**: Always create the participants directory before applying
4. **Testing**: Test with `worker_count = 0` first, then scale up
5. **Cleanup**: Destroy sessions when done to avoid costs
6. **Tags**: Session names are used for AWS cost tracking

## Cost Tracking

Each session is tagged with its name, allowing you to track costs:

```bash
# Filter by session in AWS Cost Explorer
Tag: Session = session-1
```

Resources are also tagged with:
- `Project`: k8s-lab
- `Session`: <session-name>
- `Participant`: <participant-name>
- `Cluster`: k8s-lab-<participant>
- `Role`: master|worker

## Troubleshooting

### Session config not found
```
Error: Session config not found: sessions/my-session.tfvars
```
**Solution**: Create the config file with `./scripts/manage-session.sh create-config my-session`

### No participant SSH keys
```
Error: No participant SSH keys found in: participants/my-session
```
**Solution**: Create the directory and add at least one `.pub` file:
```bash
mkdir -p participants/my-session
cp ~/.ssh/id_rsa.pub participants/my-session/yourname.pub
```

### Workspace not found
```
Error: Workspace 'my-session' not found
```
**Solution**: Initialize the session first with `./scripts/manage-session.sh init my-session`

## Examples

### Example 1: Quick Test Session
```hcl
# sessions/quick-test.tfvars
session_name = "quick-test"
worker_count = 0  # Master only
instance_type_master = "t3.small"
```

### Example 2: Training Session
```hcl
# sessions/training-dec-2025.tfvars
session_name = "training-dec-2025"
worker_count = 2
instance_type_master = "t3.medium"
instance_type_worker = "t3.small"
```

### Example 3: Large Cluster
```hcl
# sessions/production-sim.tfvars
session_name = "production-sim"
worker_count = 5
instance_type_master = "t3.large"
instance_type_worker = "t3.medium"
kubernetes_version = "1.28"
```
