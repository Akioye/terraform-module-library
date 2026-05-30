# Module: iam

Creates an IAM role with optional managed policy attachments, a custom inline policy, an EC2 instance profile, and OIDC trust for EKS IRSA (IAM Roles for Service Accounts).

One module call = one role. Call it multiple times for multiple roles.

---

## Usage — EKS node role

```hcl
module "eks_node_role" {
  source = "../../modules/iam"

  project_name = "motg"
  environment  = "dev"
  role_name    = "eks-node"
  role_description     = "Role assumed by EKS managed node group EC2 instances"
  trusted_services     = ["ec2.amazonaws.com"]
  create_instance_profile = true

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
}
```

## Usage — IRSA role (pod-level AWS access)

```hcl
module "app_s3_role" {
  source = "../../modules/iam"

  project_name     = "motg"
  environment      = "dev"
  role_name        = "app-s3-access"
  trusted_services = ["eks.amazonaws.com"]

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  k8s_namespace     = "default"
  k8s_service_account = "app-service-account"

  custom_policy_statements = [
    {
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = ["arn:aws:s3:::my-bucket/*"]
    }
  ]
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_name` | string | — | Project prefix |
| `environment` | string | — | dev, staging, or prod |
| `role_name` | string | — | Short role identifier |
| `role_description` | string | `""` | Human-readable description |
| `trusted_services` | list(string) | — | AWS service principals that can assume the role |
| `managed_policy_arns` | list(string) | `[]` | AWS managed policies to attach |
| `custom_policy_statements` | list(object) | `null` | Custom policy statements (null = no custom policy) |
| `create_instance_profile` | bool | `false` | Create EC2 instance profile |
| `max_session_duration` | number | `3600` | Max session duration in seconds |
| `oidc_provider_arn` | string | `null` | EKS OIDC provider ARN (IRSA only) |
| `oidc_provider_url` | string | `null` | EKS OIDC provider URL (IRSA only) |
| `k8s_namespace` | string | `default` | K8s namespace for IRSA |
| `k8s_service_account` | string | `null` | K8s service account for IRSA |

## Outputs

| Name | Description |
|---|---|
| `role_arn` | Role ARN — pass to EKS, RDS, EC2 |
| `role_name` | Role name |
| `role_id` | Role unique ID |
| `instance_profile_arn` | Instance profile ARN (if created) |
| `instance_profile_name` | Instance profile name (if created) |
| `custom_policy_arn` | Custom policy ARN (if created) |
