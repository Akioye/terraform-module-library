terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# -------------------------------------------------------
# IAM Role
# -------------------------------------------------------

resource "aws_iam_role" "this" {
  name                 = "${var.project_name}-${var.environment}-${var.role_name}"
  description          = var.role_description
  max_session_duration = var.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = var.trusted_services
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-${var.role_name}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# -------------------------------------------------------
# Attach AWS Managed Policies
# -------------------------------------------------------

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# -------------------------------------------------------
# Inline Custom Policy (optional)
# -------------------------------------------------------

resource "aws_iam_policy" "custom" {
  count = var.custom_policy_statements != null ? 1 : 0

  name        = "${var.project_name}-${var.environment}-${var.role_name}-policy"
  description = "Custom policy for ${var.role_name} in ${var.environment}"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = var.custom_policy_statements
  })
}

resource "aws_iam_role_policy_attachment" "custom" {
  count = var.custom_policy_statements != null ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.custom[0].arn
}

# -------------------------------------------------------
# EC2 Instance Profile (for roles assumed by EC2/EKS nodes)
# -------------------------------------------------------

resource "aws_iam_instance_profile" "this" {
  count = var.create_instance_profile ? 1 : 0

  name = "${var.project_name}-${var.environment}-${var.role_name}-profile"
  role = aws_iam_role.this.name
}

# -------------------------------------------------------
# OIDC Trust Policy Extension (for EKS service accounts)
# Used when this role will be assumed via IRSA
# -------------------------------------------------------

resource "aws_iam_role_policy" "oidc_trust" {
  count = var.oidc_provider_arn != null ? 1 : 0

  name = "${var.project_name}-${var.environment}-${var.role_name}-oidc-trust"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowOIDCAssumeRole"
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account}"
            "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}
