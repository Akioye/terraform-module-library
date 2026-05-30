output "cluster_name" {
  description = "EKS cluster name. Pass to kubectl and other tooling."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster."
  value       = aws_eks_cluster.this.version
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster. Used in kubeconfig."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane."
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group ID for worker nodes."
  value       = aws_security_group.nodes.id
}

output "node_role_arn" {
  description = "ARN of the IAM role used by worker nodes."
  value       = aws_iam_role.nodes.arn
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider. Pass to the IAM module when creating IRSA roles."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider (without https://). Pass to the IAM module for IRSA."
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for secret encryption."
  value       = aws_kms_key.eks.arn
}

output "kubeconfig_command" {
  description = "Run this command to update your local kubeconfig after cluster creation."
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${data.tls_certificate.cluster.url != "" ? "us-east-1" : "us-east-1"}"
}
