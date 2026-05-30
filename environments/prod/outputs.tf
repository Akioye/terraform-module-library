output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_public_ips" {
  description = "NAT Gateway public IPs — whitelist in external services"
  value       = module.vpc.nat_public_ips
}

output "s3_uploads_bucket" {
  description = "Uploads S3 bucket name"
  value       = module.s3_uploads.bucket_id
}

output "s3_uploads_bucket_arn" {
  description = "Uploads S3 bucket ARN"
  value       = module.s3_uploads.bucket_arn
}

output "db_endpoint" {
  description = "RDS connection endpoint"
  value       = module.rds.db_endpoint
}

output "db_name" {
  description = "Database name"
  value       = module.rds.db_name
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true   # prod endpoint is sensitive
}

output "eks_kubeconfig_command" {
  description = "Run this to connect kubectl to the cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "oidc_provider_arn" {
  description = "EKS OIDC provider ARN — use when creating IRSA roles"
  value       = module.eks.oidc_provider_arn
}
