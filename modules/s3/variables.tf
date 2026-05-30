variable "project_name" {
  description = "Project name prefix for all resource names."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "bucket_suffix" {
  description = "Suffix appended to the bucket name after project and environment (e.g. 'uploads', 'logs', 'artifacts'). Full name: <project>-<env>-<suffix>."
  type        = string
}

variable "enable_versioning" {
  description = "Enable S3 versioning. Recommended for all environments. Required if you want lifecycle rules on noncurrent versions."
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow Terraform to delete the bucket even if it contains objects. Set to true in dev only — dangerous in prod."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "ARN of a KMS key for SSE-KMS encryption. If null, uses AES256 (SSE-S3). SSE-KMS gives you more control and audit trail."
  type        = string
  default     = null
}

variable "lifecycle_rules" {
  description = "List of lifecycle rule configurations."
  type = list(object({
    id                              = string
    enabled                         = bool
    prefix                          = optional(string)
    expiration_days                 = optional(number)
    noncurrent_version_expiration_days = optional(number)
    transition_days                 = optional(number)
    transition_storage_class        = optional(string)
  }))
  default = []
}

variable "cors_rules" {
  description = "CORS rules for web-facing buckets. Leave empty for most buckets."
  type = list(object({
    allowed_headers = optional(list(string))
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = []
}

variable "additional_bucket_policy_statements" {
  description = "Additional IAM policy statements to merge into the bucket policy (beyond the default TLS-only deny). Useful for cross-account access."
  type        = list(any)
  default     = []
}
