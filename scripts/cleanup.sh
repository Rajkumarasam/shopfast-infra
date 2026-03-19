#!/bin/bash
# cleanup.sh — Tear down Shopfast infrastructure for a given environment
# Usage: ./scripts/cleanup.sh [dev|staging|prod]
# WARNING: This destroys all infrastructure in the specified environment.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

ENV=${1:-dev}

if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
  error "Invalid environment. Use: dev | staging | prod"
fi

warn "=========================================="
warn " WARNING: This will DESTROY all"
warn " infrastructure for environment: $ENV"
warn "=========================================="
read -rp "Type the environment name to confirm ('$ENV'): " CONFIRM

[[ "$CONFIRM" == "$ENV" ]] || { info "Aborted — environment name did not match."; exit 0; }

TERRAFORM_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"
cd "$TERRAFORM_DIR"

info "Selecting workspace: $ENV"
terraform workspace select "$ENV" || error "Workspace $ENV not found"

info "Running terraform destroy..."
terraform destroy \
  -var="environment=$ENV" \
  -var="project_name=shopfast" \
  -auto-approve

info "Cleanup complete for environment: $ENV"
