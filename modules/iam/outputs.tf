output "role_arn" {
  description = "ARN of the IAM role. Pass to EKS, RDS, or EC2 resources that need to assume it."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role."
  value       = aws_iam_role.this.name
}

output "role_id" {
  description = "Unique ID of the IAM role."
  value       = aws_iam_role.this.id
}

output "instance_profile_arn" {
  description = "ARN of the EC2 instance profile. Pass to EKS node groups and EC2 launch templates."
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].arn : null
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile."
  value       = var.create_instance_profile ? aws_iam_instance_profile.this[0].name : null
}

output "custom_policy_arn" {
  description = "ARN of the custom inline policy, if created."
  value       = var.custom_policy_statements != null ? aws_iam_policy.custom[0].arn : null
}
