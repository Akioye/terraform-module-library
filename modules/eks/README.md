# Module: eks

Creates a production-grade EKS cluster with managed node groups, KMS secret encryption, OIDC provider for IRSA, and the three core add-ons (vpc-cni, coredns, kube-proxy).

---

## Architecture

```
                    ┌────────────────────────────────────────┐
                    │          EKS Cluster (Control Plane)    │
                    │  API server · etcd · scheduler · CM     │
                    │  KMS-encrypted secrets                  │
                    │  CloudWatch logs: api/audit/auth/...    │
                    └──────────────┬─────────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
   ┌──────────▼──────────┐         │         ┌──────────▼──────────┐
   │  Managed Node Group │         │         │  Managed Node Group │
   │  Private subnet AZ-a│         │         │  Private subnet AZ-b│
   │  t3.medium (dev)    │         │         │  t3.medium (dev)    │
   └─────────────────────┘         │         └─────────────────────┘
                                   │
                        ┌──────────▼──────────┐
                        │   OIDC Provider      │
                        │   Enables IRSA:      │
                        │   pods → IAM roles   │
                        └─────────────────────┘
```

## Usage

```hcl
module "eks" {
  source = "../../modules/eks"

  project_name       = "motg"
  environment        = "dev"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  kubernetes_version  = "1.29"
  node_instance_type  = "t3.medium"
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 4

  endpoint_public_access = true     # false in prod — use VPN
  node_capacity_type     = "SPOT"   # ON_DEMAND in prod
}
```

## Connect to the cluster after apply

```bash
aws eks update-kubeconfig --name motg-dev --region us-east-1
kubectl get nodes
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_name` | string | — | Project prefix |
| `environment` | string | — | dev, staging, or prod |
| `vpc_id` | string | — | VPC ID |
| `private_subnet_ids` | list(string) | — | Private subnets for nodes |
| `public_subnet_ids` | list(string) | — | Public subnets for LB discovery |
| `kubernetes_version` | string | `1.29` | K8s version |
| `endpoint_public_access` | bool | `true` | Expose API server publicly |
| `public_access_cidrs` | list(string) | `["0.0.0.0/0"]` | Restrict API access by IP |
| `node_instance_type` | string | `t3.medium` | Node EC2 instance type |
| `node_capacity_type` | string | `ON_DEMAND` | ON_DEMAND or SPOT |
| `node_disk_size` | number | `20` | Node EBS volume size (GB) |
| `node_desired_size` | number | `2` | Desired node count |
| `node_min_size` | number | `1` | Minimum node count |
| `node_max_size` | number | `4` | Maximum node count |
| `cluster_log_types` | list(string) | all 5 types | Control plane logs to CloudWatch |

## Outputs

| Name | Description |
|---|---|
| `cluster_name` | Cluster name — use in kubectl/helm |
| `cluster_endpoint` | API server endpoint |
| `cluster_arn` | Cluster ARN |
| `cluster_version` | Running K8s version |
| `cluster_certificate_authority_data` | CA data for kubeconfig (sensitive) |
| `oidc_provider_arn` | Pass to IAM module for IRSA roles |
| `oidc_provider_url` | Pass to IAM module for IRSA roles |
| `node_security_group_id` | Node SG — reference for RDS ingress |
| `kms_key_arn` | KMS key used for secret encryption |
| `kubeconfig_command` | Command to connect after apply |

## Environment differences

| Variable | dev | staging | prod |
|---|---|---|---|
| `node_instance_type` | `t3.small` | `t3.medium` | `m5.large` |
| `node_capacity_type` | `SPOT` | `SPOT` | `ON_DEMAND` |
| `endpoint_public_access` | `true` | `true` | `false` |
| `node_desired_size` | `1` | `2` | `3` |
| `node_max_size` | `3` | `5` | `10` |

## IRSA — giving pods AWS permissions

After the cluster is created, use the IAM module to create IRSA roles:

```hcl
module "s3_access_role" {
  source = "../../modules/iam"

  project_name        = "motg"
  environment         = "dev"
  role_name           = "app-s3"
  trusted_services    = []
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  k8s_namespace       = "default"
  k8s_service_account = "app"

  custom_policy_statements = [{
    Effect   = "Allow"
    Action   = ["s3:GetObject", "s3:PutObject"]
    Resource = ["${module.app_bucket.bucket_arn}/*"]
  }]
}
```
