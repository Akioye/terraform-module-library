terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# -------------------------------------------------------
# VPC
# -------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  cidr_block           = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  enable_nat_gateway = true
  single_nat_gateway = true    # still single NAT in staging — cost saving

  enable_flow_logs         = true   # enabled in staging to mirror prod
  flow_logs_retention_days = 30
}

# -------------------------------------------------------
# IAM — EKS Node Role
# -------------------------------------------------------

module "eks_node_role" {
  source = "../../modules/iam"

  project_name     = var.project_name
  environment      = var.environment
  role_name        = "eks-node"
  role_description = "Role assumed by EKS managed node group EC2 instances"
  trusted_services = ["ec2.amazonaws.com"]

  create_instance_profile = true

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
}

# -------------------------------------------------------
# IAM — RDS Monitoring Role
# -------------------------------------------------------

module "rds_monitoring_role" {
  source = "../../modules/iam"

  project_name     = var.project_name
  environment      = var.environment
  role_name        = "rds-monitoring"
  role_description = "Role for RDS Enhanced Monitoring"
  trusted_services = ["monitoring.rds.amazonaws.com"]

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole",
  ]
}

# -------------------------------------------------------
# S3 — Application Uploads Bucket
# -------------------------------------------------------

module "s3_uploads" {
  source = "../../modules/s3"

  project_name  = var.project_name
  environment   = var.environment
  bucket_suffix = "uploads"

  enable_versioning = true
  force_destroy     = false   # staging — don't allow destroy with objects

  lifecycle_rules = [
    {
      id      = "expire-old-versions"
      enabled = true
      noncurrent_version_expiration_days = 60
    },
    {
      id              = "transition-to-ia"
      enabled         = true
      transition_days = 30
      transition_storage_class = "STANDARD_IA"
    }
  ]
}

# -------------------------------------------------------
# RDS — Postgres Database
# -------------------------------------------------------

module "rds" {
  source = "../../modules/rds"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  allowed_cidr_blocks = [var.vpc_cidr]

  engine                 = "postgres"
  engine_version         = "15.4"
  parameter_group_family = "postgres15"
  instance_class         = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password

  multi_az              = false   # kept false — free tier constraint
  deletion_protection   = false
  skip_final_snapshot   = false   # staging takes a final snapshot
  backup_retention_days = 7

  enable_enhanced_monitoring  = false  # free tier — skip enhanced monitoring
  enable_performance_insights = true
  monitoring_role_arn         = module.rds_monitoring_role.role_arn
  auto_minor_version_upgrade  = true
}

# -------------------------------------------------------
# EKS — Kubernetes Cluster
# -------------------------------------------------------

module "eks" {
  source = "../../modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  kubernetes_version = var.kubernetes_version

  endpoint_public_access = true
  public_access_cidrs    = ["0.0.0.0/0"]

  node_instance_type = var.eks_node_instance_type
  node_capacity_type = "SPOT"     # spot in staging — cost saving
  node_disk_size     = 20
  node_desired_size  = 1
  node_min_size      = 1
  node_max_size      = 3
}
