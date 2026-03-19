#!/bin/bash
# health_check.sh — Check health of Shopfast infrastructure and application
# Usage: ./scripts/health_check.sh [dev|staging|prod]

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[FAIL]${NC}  $1"; }
section() { echo -e "\n${BLUE}===== $1 =====${NC}"; }

ENV=${1:-dev}
APP_NAME="shopfast"
FAIL_COUNT=0

case "$ENV" in
  dev)     NAMESPACE="shopfast-dev" ;;
  staging) NAMESPACE="shopfast-staging" ;;
  prod)    NAMESPACE="shopfast-prod" ;;
  *)       echo "Usage: $0 [dev|staging|prod]"; exit 1 ;;
esac

echo "Health Check — Shopfast ($ENV) — $(date '+%Y-%m-%d %H:%M:%S')"
echo "==========================================================="

# --- 1. AWS Connectivity ---
section "AWS Connectivity"
if aws sts get-caller-identity >/dev/null 2>&1; then
  ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
  info "AWS credentials valid (Account: $ACCOUNT)"
else
  error "AWS credentials not configured or expired"; ((FAIL_COUNT++))
fi

# --- 2. EC2 Instance Health ---
section "EC2 Instances"
INSTANCES=$(aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=$ENV" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}" \
  --output table 2>/dev/null || echo "")

if [[ -n "$INSTANCES" ]]; then
  info "Running EC2 instances found"
  echo "$INSTANCES"
else
  warn "No running EC2 instances found for environment: $ENV"
fi

# --- 3. S3 Bucket Health ---
section "S3 Buckets"
BUCKETS=$(aws s3api list-buckets \
  --query "Buckets[?contains(Name, 'shopfast')].Name" \
  --output text 2>/dev/null || echo "")

if [[ -n "$BUCKETS" ]]; then
  for BUCKET in $BUCKETS; do
    if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
      info "Bucket accessible: $BUCKET"
    else
      error "Bucket inaccessible: $BUCKET"; ((FAIL_COUNT++))
    fi
  done
else
  warn "No shopfast S3 buckets found"
fi

# --- 4. Kubernetes Pod Health ---
section "Kubernetes Pods ($NAMESPACE)"
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
  if [[ -z "$PODS" ]]; then
    warn "No pods found in namespace $NAMESPACE"
  else
    while IFS= read -r pod_line; do
      POD_NAME=$(echo "$pod_line" | awk '{print $1}')
      POD_STATUS=$(echo "$pod_line" | awk '{print $3}')
      POD_READY=$(echo "$pod_line" | awk '{print $2}')
      if [[ "$POD_STATUS" == "Running" ]]; then
        info "Pod $POD_NAME — $POD_STATUS ($POD_READY)"
      else
        error "Pod $POD_NAME — $POD_STATUS ($POD_READY)"; ((FAIL_COUNT++))
      fi
    done <<< "$PODS"
  fi
else
  warn "Namespace $NAMESPACE does not exist — environment may not be provisioned"
fi

# --- 5. Kubernetes Deployment Health ---
section "Kubernetes Deployments"
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  DEPLOY=$(kubectl get deployment "${APP_NAME}-app" -n "$NAMESPACE" \
    --no-headers 2>/dev/null || echo "")
  if [[ -n "$DEPLOY" ]]; then
    DESIRED=$(echo "$DEPLOY" | awk '{print $2}')
    READY=$(echo "$DEPLOY" | awk '{print $4}')
    if [[ "$DESIRED" == "$READY" ]]; then
      info "Deployment ${APP_NAME}-app — Ready ($READY/$DESIRED replicas)"
    else
      error "Deployment ${APP_NAME}-app — Not ready ($READY/$DESIRED replicas)"; ((FAIL_COUNT++))
    fi
  else
    warn "Deployment ${APP_NAME}-app not found in $NAMESPACE"
  fi
fi

# --- 6. CloudWatch Alarms ---
section "CloudWatch Alarms"
ALARMS=$(aws cloudwatch describe-alarms \
  --alarm-name-prefix "shopfast-$ENV" \
  --state-value ALARM \
  --query "MetricAlarms[].AlarmName" \
  --output text 2>/dev/null || echo "")

if [[ -z "$ALARMS" || "$ALARMS" == "None" ]]; then
  info "No CloudWatch alarms in ALARM state"
else
  for ALARM in $ALARMS; do
    error "CloudWatch alarm firing: $ALARM"; ((FAIL_COUNT++))
  done
fi

# --- Summary ---
echo ""
echo "==========================================================="
if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo -e "${GREEN}All health checks passed. ($ENV)${NC}"
else
  echo -e "${RED}$FAIL_COUNT check(s) failed. Review errors above. ($ENV)${NC}"
  exit 1
fi
