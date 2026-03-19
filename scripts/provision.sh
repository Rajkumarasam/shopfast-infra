#!/bin/bash
# provision.sh — Provision the Shopfast environment using Terraform
# Usage: ./scripts/provision.sh [dev|staging|prod]

set -euo pipefail

# --- Colour output ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Validate environment argument ---
ENV=${1:-dev}
if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
  error "Invalid environment '$ENV'. Use: dev | staging | prod"
fi

TERRAFORM_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"

info "Starting provisioning for environment: $ENV"
info "Terraform directory: $TERRAFORM_DIR"

# --- Pre-flight checks ---
info "Running pre-flight checks..."

command -v terraform >/dev/null 2>&1 || error "terraform not found. Install from https://terraform.io"
command -v aws >/dev/null 2>&1      || error "aws CLI not found. Install from https://aws.amazon.com/cli"

# Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  error "AWS credentials not configured. Run: aws configure"
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "ap-south-1")
info "AWS Account: $AWS_ACCOUNT | Region: $AWS_REGION"

# --- Terraform init ---
info "Initialising Terraform..."
cd "$TERRAFORM_DIR"
terraform init -input=false

# --- Terraform workspace ---
info "Selecting workspace: $ENV"
terraform workspace select "$ENV" 2>/dev/null || terraform workspace new "$ENV"

# --- Terraform plan ---
info "Running terraform plan..."
terraform plan \
  -var="environment=$ENV" \
  -var="project_name=shopfast" \
  -out="/tmp/shopfast-$ENV.tfplan"

# --- Confirm before apply (skip for dev) ---
if [[ "$ENV" != "dev" ]]; then
  warn "You are about to apply changes to $ENV environment."
  read -rp "Type 'yes' to confirm: " CONFIRM
  [[ "$CONFIRM" == "yes" ]] || { info "Aborted."; exit 0; }
fi

# --- Terraform apply ---
info "Applying Terraform plan..."
terraform apply "/tmp/shopfast-$ENV.tfplan"

# --- Output summary ---
info "Provisioning complete for environment: $ENV"
terraform output
