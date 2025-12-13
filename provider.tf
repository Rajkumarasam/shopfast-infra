provider "aws" {
  region = "us-east-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # THIS IS THE BACKEND BLOCK
  # We tell Terraform: "Don't save memory on my laptop. Save it in the cloud."
  backend "s3" {
    bucket         = "shopfast-state-rajkumar-2025" # MUST MATCH YOUR SCRIPT
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "shopfast-locks"             # MUST MATCH YOUR SCRIPT
    encrypt        = true
  }
}
