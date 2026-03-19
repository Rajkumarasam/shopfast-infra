#!/bin/bash
# deploy.sh — Deploy a new version of the Shopfast application
# Usage: ./scripts/deploy.sh [dev|staging|prod] <docker-image-tag>

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()    { echo -e "${BLUE}[STEP]${NC}  $1"; }

ENV=${1:-dev}
IMAGE_TAG=${2:-latest}
APP_NAME="shopfast"
DOCKER_IMAGE="rajkumarasam/${APP_NAME}:${IMAGE_TAG}"

if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
  error "Invalid environment. Use: dev | staging | prod"
fi

info "Deploying $DOCKER_IMAGE to $ENV"

# --- Pre-deployment checks ---
step "1/6 — Pre-deployment checks"

command -v docker >/dev/null 2>&1    || error "docker not found"
command -v kubectl >/dev/null 2>&1   || error "kubectl not found"
command -v aws >/dev/null 2>&1       || error "aws CLI not found"

# Verify image exists on DockerHub
info "Verifying image: $DOCKER_IMAGE"
docker manifest inspect "$DOCKER_IMAGE" >/dev/null 2>&1 || \
  error "Image $DOCKER_IMAGE not found on DockerHub. Build and push it first."

# --- Environment config ---
step "2/6 — Loading environment configuration"

case "$ENV" in
  dev)     NAMESPACE="shopfast-dev";     REPLICAS=1 ;;
  staging) NAMESPACE="shopfast-staging"; REPLICAS=2 ;;
  prod)    NAMESPACE="shopfast-prod";    REPLICAS=3 ;;
esac

info "Namespace: $NAMESPACE | Replicas: $REPLICAS"

# --- Create namespace if needed ---
step "3/6 — Ensuring namespace exists"
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || \
  kubectl create namespace "$NAMESPACE"

# --- Pull latest image ---
step "4/6 — Pulling Docker image"
docker pull "$DOCKER_IMAGE"

# --- Update deployment ---
step "5/6 — Updating Kubernetes deployment"
kubectl set image deployment/${APP_NAME}-app \
  ${APP_NAME}-app=${DOCKER_IMAGE} \
  -n "$NAMESPACE" 2>/dev/null || {
  warn "Deployment not found. Applying manifests from scratch..."
  kubectl apply -f k8s/ -n "$NAMESPACE"
}

kubectl scale deployment/${APP_NAME}-app --replicas="$REPLICAS" -n "$NAMESPACE" 2>/dev/null || true

# --- Wait for rollout ---
step "6/6 — Waiting for rollout"
if kubectl rollout status deployment/${APP_NAME}-app \
    -n "$NAMESPACE" --timeout=120s; then
  info "Deployment successful."
  info "Image: $DOCKER_IMAGE | Environment: $ENV | Replicas: $REPLICAS"
else
  error "Rollout failed. Run: kubectl rollout undo deployment/${APP_NAME}-app -n $NAMESPACE"
fi

# --- Post-deployment summary ---
echo ""
info "=== Deployment Summary ==="
kubectl get pods -n "$NAMESPACE"
kubectl get svc  -n "$NAMESPACE"
