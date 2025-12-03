# Terraform Backend Configuration for Parallel Sessions
#
# This configuration enables multiple sessions to run in parallel by using:
# - Workspaces: Each session gets its own workspace
# - S3 Backend: Stores state remotely with locking via DynamoDB
#
# SETUP INSTRUCTIONS:
# 1. Create an S3 bucket for Terraform state:
#    aws s3api create-bucket \
#      --bucket YOUR-BUCKET-NAME \
#      --region eu-west-1 \
#      --create-bucket-configuration LocationConstraint=eu-west-1
#
# 2. Enable versioning on the bucket:
#    aws s3api put-bucket-versioning \
#      --bucket YOUR-BUCKET-NAME \
#      --versioning-configuration Status=Enabled
#
# 3. Create a DynamoDB table for state locking:
#    aws dynamodb create-table \
#      --table-name terraform-state-lock \
#      --attribute-definitions AttributeName=LockID,AttributeType=S \
#      --key-schema AttributeName=LockID,KeyType=HASH \
#      --billing-mode PAY_PER_REQUEST \
#      --region eu-west-1
#
# 4. Uncomment the terraform block below and replace YOUR-BUCKET-NAME
#
# 5. Initialize Terraform:
#    terraform init
#
# FOR LOCAL DEVELOPMENT (no S3):
# Comment out the backend "s3" block below and Terraform will use local state files

terraform {
  # Uncomment this block to use S3 backend for parallel sessions
  # backend "s3" {
  #   bucket         = "YOUR-BUCKET-NAME"  # Replace with your S3 bucket name
  #   key            = "kubernetes-aws-lab/terraform.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  #
  #   # Workspace prefix allows each session to have its own state file
  #   # State will be stored as: s3://bucket/kubernetes-aws-lab/env:/session-1/terraform.tfstate
  #   workspace_key_prefix = "env"
  # }
}

# IMPORTANT NOTES:
# - Each session should use a unique workspace (e.g., session-1, session-2)
# - Workspace names should match the session_name in your tfvars files
# - Use the scripts/manage-session.sh script to easily manage sessions
# - Without S3 backend, state files are stored locally in terraform.tfstate.d/
