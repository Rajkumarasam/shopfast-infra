output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ec2_public_ip" {
  description = "EC2 public IP"
  value       = module.ec2.public_ip
}

output "s3_bucket_name" {
  description = "S3 bucket name for assets"
  value       = module.s3.bucket_name
}
