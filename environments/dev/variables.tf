variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources."
  type        = string
  default     = "motg"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

# VPC

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to deploy into. Dev uses one AZ to minimize cost."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# RDS

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the default database."
  type        = string
  default     = "motgdb"
}

variable "db_username" {
  description = "Master DB username."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master DB password."
  type        = string
  sensitive   = true
}

# EKS

variable "kubernetes_version" {
  description = "Kubernetes version."
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes."
  type        = string
  default     = "t3.micro"
}
