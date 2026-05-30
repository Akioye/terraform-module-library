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

variable "vpc_id" {
  description = "VPC ID where the RDS instance will be deployed. Use the VPC module's vpc_id output."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group. Use the VPC module's private_subnet_ids output."
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect to the DB. Usually the VPC CIDR or the private subnet CIDRs."
  type        = list(string)
}

# Engine

variable "engine" {
  description = "Database engine (e.g. mysql, postgres)."
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Engine version (e.g. '15.4' for Postgres, '8.0' for MySQL)."
  type        = string
  default     = "15.4"
}

variable "parameter_group_family" {
  description = "DB parameter group family (e.g. postgres15, mysql8.0). Must match engine and engine_version."
  type        = string
  default     = "postgres15"
}

variable "db_parameters" {
  description = "List of DB parameter overrides. Applied to the parameter group."
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string)
  }))
  default = []
}

# Instance

variable "instance_class" {
  description = "RDS instance class (e.g. db.t3.micro for dev, db.r5.large for prod)."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper limit for storage autoscaling in GB. Set to 0 to disable autoscaling."
  type        = number
  default     = 100
}

# Database

variable "db_name" {
  description = "Name of the default database to create."
  type        = string
}

variable "db_username" {
  description = "Master username for the database."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the database. In production, pass this from AWS Secrets Manager."
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Port the database listens on. Defaults to 5432 (Postgres)."
  type        = number
  default     = 5432
}

# Availability

variable "multi_az" {
  description = "Deploy a standby replica in a second AZ. Recommended for staging/prod."
  type        = bool
  default     = false
}

# Backups & Maintenance

variable "backup_retention_days" {
  description = "Number of days to retain automated backups. 0 disables backups."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 0 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 0 and 35."
  }
}

variable "backup_window" {
  description = "Daily time range (UTC) for automated backups (e.g. '03:00-04:00')."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly time range for maintenance (e.g. 'Mon:04:00-Mon:05:00')."
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy. Set true in dev to allow clean teardown. Always false in prod."
  type        = bool
  default     = false
}

# Protection

variable "deletion_protection" {
  description = "Prevent accidental deletion of the DB. Always true in prod."
  type        = bool
  default     = false
}

variable "auto_minor_version_upgrade" {
  description = "Automatically apply minor engine upgrades during maintenance windows."
  type        = bool
  default     = true
}

# Monitoring

variable "enable_enhanced_monitoring" {
  description = "Enable RDS Enhanced Monitoring (1-minute intervals). Requires monitoring_role_arn."
  type        = bool
  default     = false
}

variable "monitoring_role_arn" {
  description = "ARN of the IAM role for RDS Enhanced Monitoring. Required when enable_enhanced_monitoring = true."
  type        = string
  default     = null
}

variable "enable_performance_insights" {
  description = "Enable RDS Performance Insights. Highly recommended for staging and prod."
  type        = bool
  default     = false
}
