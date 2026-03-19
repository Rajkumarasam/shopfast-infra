# shopfast-infra

Shell scripts and Terraform modules to provision, deploy, health-check, and tear down the infrastructure for **Shopfast** — a simulated retail/e-commerce platform on AWS.

---

## What This Project Does

| Script | Purpose |
|--------|---------|
| `scripts/bootstrap.sh` | One-time setup — creates S3 bucket and DynamoDB table for Terraform remote state |
| `scripts/provision.sh` | Provisions full AWS infrastructure via Terraform (VPC, EC2, S3) for a given environment |
| `scripts/deploy.sh` | Deploys a new Docker image version to the Kubernetes cluster |
| `scripts/health_check.sh` | Checks health of EC2 instances, S3 buckets, K8s pods, and CloudWatch alarms |
| `scripts/cleanup.sh` | Tears down all infrastructure for a given environment via terraform destroy |

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  AWS (ap-south-1)                   │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │  VPC (10.0.0.0/16)                           │   │
│  │                                              │   │
│  │  ┌─────────────────┐  ┌─────────────────┐   │   │
│  │  │ Public Subnet   │  │ Public Subnet   │   │   │
│  │  │ ap-south-1a     │  │ ap-south-1b     │   │   │
│  │  │                 │  │                 │   │   │
│  │  │  EC2 t3.micro   │  │                 │   │   │
│  │  │  (app server)   │  │                 │   │   │
│  │  └─────────────────┘  └─────────────────┘   │   │
│  │                                              │   │
│  │  Internet Gateway → Route Table              │   │
│  └──────────────────────────────────────────────┘   │
│                                                     │
│  S3 Bucket (assets — versioned, encrypted)          │
│  S3 Bucket (terraform remote state)                 │
│  DynamoDB Table (terraform state lock)              │
└─────────────────────────────────────────────────────┘
```

---

## Project Structure

```
shopfast-infra/
├── scripts/
│   ├── bootstrap.sh      # One-time remote state setup
│   ├── provision.sh      # Terraform plan + apply per environment
│   ├── deploy.sh         # Docker image deploy to Kubernetes
│   ├── health_check.sh   # Infrastructure + app health checks
│   └── cleanup.sh        # Terraform destroy per environment
├── terraform/
│   ├── provider.tf       # AWS provider + S3 remote state backend
│   ├── main.tf           # Root module — calls vpc, ec2, s3 modules
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── vpc/          # VPC, subnets, IGW, route tables
│       ├── ec2/          # EC2 instance, security group
│       └── s3/           # S3 assets bucket (versioned + encrypted)
└── .gitignore
```

---

## Usage

### Step 1 — Bootstrap remote state (run once)

```bash
chmod +x scripts/*.sh
./scripts/bootstrap.sh
```

Creates the S3 bucket and DynamoDB table needed for Terraform remote state.

### Step 2 — Provision infrastructure

```bash
# Provision dev environment
./scripts/provision.sh dev

# Provision staging
./scripts/provision.sh staging

# Provision prod (requires manual confirmation)
./scripts/provision.sh prod
```

### Step 3 — Deploy application

```bash
# Deploy image tag v1.2.0 to dev
./scripts/deploy.sh dev v1.2.0

# Deploy latest to staging
./scripts/deploy.sh staging latest
```

### Step 4 — Run health checks

```bash
./scripts/health_check.sh dev
```

Checks:
- AWS credential validity
- EC2 instance running state
- S3 bucket accessibility
- Kubernetes pod status and readiness
- CloudWatch alarms in ALARM state

### Step 5 — Tear down

```bash
# Destroy dev environment (confirms environment name before proceeding)
./scripts/cleanup.sh dev
```

---

## Terraform Modules

**vpc module** — VPC with 2 public subnets, Internet Gateway, route tables

**ec2 module** — t3.micro EC2 instance with security group (HTTP 80, app port 5000, SSH 22), encrypted EBS volume

**s3 module** — Assets bucket with versioning enabled, AES256 server-side encryption, public access blocked

---

## Environment Support

All scripts accept `dev`, `staging`, or `prod` as the first argument. Terraform workspaces are used to isolate state per environment. Production environments require manual confirmation before apply or destroy.

---

## Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.5.0
- kubectl (for deploy and health check scripts)
- Docker (for deploy script)

---

## Author

**Rajkumar Asam** — Software Engineer (DevOps)
[linkedin.com/in/rajkumarasam17](https://linkedin.com/in/rajkumarasam17) | [github.com/Rajkumarasam](https://github.com/Rajkumarasam)
