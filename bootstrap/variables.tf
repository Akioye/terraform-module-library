variable "aws_region" {
  description = "AWS region to deploy the remote state infrastructure"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Must be a valid AWS region (e.g. us-east-1, eu-west-2)."
  }
}

variable "project_name" {
  description = "Prefix used for all resource names. Use lowercase letters, numbers, and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,24}$", var.project_name))
    error_message = "project_name must be 3–25 chars, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}
