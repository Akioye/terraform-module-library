output "state_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state. Reference this in each environment's backend.tf."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 state bucket."
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB lock table. Reference this in each environment's backend.tf."
  value       = aws_dynamodb_table.terraform_locks.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB lock table."
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "backend_config_snippet" {
  description = "Copy-paste this into each environment's backend.tf. Replace <ENV> with dev, staging, or prod."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "<ENV>/terraform.tfstate"
        region         = "${aws_s3_bucket.terraform_state.region}"
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
        encrypt        = true
      }
    }
  EOT
}
