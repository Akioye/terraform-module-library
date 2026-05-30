# Environment: staging

The staging environment. Mirrors prod configuration as closely as possible while staying on free-tier instance sizes. Used to validate changes before promoting to prod.

---

## What it creates

| Resource | Config |
|---|---|
| VPC | `10.1.0.0/16` · 2 public + 2 private subnets · 1 NAT gateway |
| EKS | `t3.small` · SPOT nodes · 1 desired · 3 max |
| RDS | `db.t3.micro` · Postgres 15.4 · no Multi-AZ |
| S3 | Uploads bucket · versioning on · lifecycle transitions to IA after 30 days |
| IAM | EKS node role · RDS monitoring role |

---

## Key staging-specific settings

- `enable_flow_logs = true` — VPC flow logs enabled, retained 30 days, mirrors prod
- `skip_final_snapshot = false` — takes a final RDS snapshot before destroy, unlike dev
- `force_destroy = false` — S3 bucket cannot be destroyed if it contains objects
- `enable_performance_insights = true` — DB performance visibility, same as prod
- `backup_retention_days = 7` — full week of backups
- VPC CIDR `10.1.0.0/16` — separate from dev (`10.0`) and prod (`10.2`) to allow future VPC peering without conflicts

---

## Usage

```bash
cd environments/staging

# First time only
terraform init

# See what will be created
terraform plan

# Apply
terraform apply

# Connect to the cluster after apply
aws eks update-kubeconfig --name motg-staging --region us-east-1
kubectl get nodes
```

---

## Passing secrets

```bash
export TF_VAR_db_username=myuser
export TF_VAR_db_password=mypassword
terraform apply
```

---

## Promotion flow

Changes move through environments in this order:

```
dev → staging → prod
```

1. Test your change in dev
2. Open a PR — CI runs `terraform plan` on all three environments
3. Review the staging plan output in the PR comment
4. Merge → manually apply staging
5. Validate staging works
6. Apply prod

---

## Inputs

| Name | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `project_name` | `motg` | Project prefix |
| `environment` | `staging` | Environment name |
| `vpc_cidr` | `10.1.0.0/16` | VPC CIDR block |
| `availability_zones` | `us-east-1a/b` | AZs to deploy into |
| `public_subnet_cidrs` | `10.1.1-2.0/24` | Public subnet CIDRs |
| `private_subnet_cidrs` | `10.1.11-12.0/24` | Private subnet CIDRs |
| `db_instance_class` | `db.t3.micro` | RDS instance size |
| `db_name` | `motgdb` | Database name |
| `db_username` | — | Master DB username (sensitive) |
| `db_password` | — | Master DB password (sensitive) |
| `kubernetes_version` | `1.29` | EKS Kubernetes version |
| `eks_node_instance_type` | `t3.small` | EKS node instance type |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID |
| `public_subnet_ids` | Public subnet IDs |
| `private_subnet_ids` | Private subnet IDs |
| `nat_public_ips` | NAT Gateway EIPs — whitelist externally |
| `s3_uploads_bucket` | Uploads bucket name |
| `db_endpoint` | RDS connection endpoint |
| `db_name` | Database name |
| `eks_cluster_name` | EKS cluster name |
| `eks_cluster_endpoint` | EKS API server endpoint |
| `eks_kubeconfig_command` | kubectl connect command |
| `oidc_provider_arn` | OIDC ARN for IRSA roles |

---

## Remote state

```
bucket: motg-terraform-state-us-east-1
key:    staging/terraform.tfstate
lock:   motg-terraform-locks (DynamoDB)
```
