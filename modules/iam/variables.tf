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

variable "role_name" {
  description = "Short descriptive name for the role (e.g. eks-node, rds-monitoring, app-server). Combined with project and environment to form the full role name."
  type        = string
}

variable "role_description" {
  description = "Human-readable description of what this role is for."
  type        = string
  default     = ""
}

variable "trusted_services" {
  description = "List of AWS service principals allowed to assume this role (e.g. ['ec2.amazonaws.com', 'eks.amazonaws.com'])."
  type        = list(string)
}

variable "managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach to the role (e.g. 'arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy')."
  type        = list(string)
  default     = []
}

variable "custom_policy_statements" {
  description = "List of IAM policy statement objects for a custom inline policy. Set to null to skip custom policy creation."
  type = list(object({
    Sid      = optional(string)
    Effect   = string
    Action   = list(string)
    Resource = list(string)
  }))
  default = null
}

variable "create_instance_profile" {
  description = "Set to true to create an EC2 instance profile from this role. Required for EC2 and EKS node groups."
  type        = bool
  default     = false
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds when assuming this role. Between 3600 (1h) and 43200 (12h)."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200 seconds."
  }
}

# OIDC / IRSA variables (used only when creating roles for EKS service accounts)

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider. Required when creating IRSA roles for EKS workloads."
  type        = string
  default     = null
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider (without https://). Required when oidc_provider_arn is set."
  type        = string
  default     = null
}

variable "k8s_namespace" {
  description = "Kubernetes namespace of the service account that will assume this role."
  type        = string
  default     = "default"
}

variable "k8s_service_account" {
  description = "Kubernetes service account name that will assume this role."
  type        = string
  default     = null
}
