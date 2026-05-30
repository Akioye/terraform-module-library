# Environment: prod

The production environment. Tightest security settings, highest reliability config, free-tier instance sizes. Apply here only after staging has been validated.

---

## What it creates

| Resource | Config |
|---|---|
| VPC | `10.2.0.0/16` · 2 public + 2 private subnets · 1 NAT per AZ |
| EKS | `t3.small` · ON_DEMAND nodes · 2 desired · 4 max |
| RDS | `db.t3.micro` · Postgres 15.4 · deletion protection on |
| S3 | Uploads bucket · versioning · IA after 30 days · Glacier after 90 days |
| IAM | EKS node role · RDS monitoring role |

---

## Key prod-only settings

- `single_nat_gateway = false` — one NAT gateway per AZ for high availability
- `node_capacity_type = "ON_DEMAND"` — no spot interruptions in prod
- `deletion_protection = true` — RDS cannot be deleted without manually disabling this first
- `skip_final_snapshot = false` — always snapshots before any destroy
- `force_destroy = false` — S3 bucket is protected from accidental deletion
- `enable_flow_logs = true` — 90 day retention for security and compliance
- `backup_retention_days = 14` — two weeks of RDS backups
- `auto_minor_version_upgrade = false` — manual control over DB upgrades in prod
- `endpoint_public_access` restricted to `allowed_ips` — lock this down to your VPN IP before going live

---

## Before applying to prod

```bash
# 1. Restrict API access — edit terraform.tfvars
allowed_ips = ["your.vpn.ip/32"]

# 2. Make sure staging was applied and validated first

# 3. Plan and review carefully
cd environments/prod
export TF_VAR_db_username=myuser
export TF_VAR_db_password=mypassword
terraform plan

# 4. Apply only after reviewing the plan output
terraform apply
```

> **Never run `terraform apply` in prod from a local machine in a team setting.** Use the CI pipeline with manual approval gates.

---

## Passing secrets

```bash
export TF_VAR_db_username=myuser
export TF_VAR_db_password=mypassword
terraform apply
```

In a real production setup, pull the password from AWS Secrets Manager instead:

```hcl
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "motg/prod/db-credentials"
}
```

---

## Destroying prod (careful)

Prod has two layers of destroy protection:

1. `deletion_protection = true` on RDS — Terraform will error if you try to destroy without disabling this first
2. `force_destroy = false` on S3 — bucket must be empty before it can be deleted

To destroy prod intentionally:
```bash
# Step 1 — disable deletion protection
# Edit main.tf: deletion_protection = false
terraform apply

# Step 2 — empty the S3 bucket manually via AWS console or CLI

# Step 3 — destroy
terraform destroy
```

---

## Inputs

| Name | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `project_name` | `motg` | Project prefix |
| `environment` | `prod` | Environment name |
| `vpc_cidr` | `10.2.0.0/16` | VPC CIDR block |
| `availability_zones` | `us-east-1a/b` | AZs to deploy into |
| `public_subnet_cidrs` | `10.2.1-2.0/24` | Public subnet CIDRs |
| `private_subnet_cidrs` | `10.2.11-12.0/24` | Private subnet CIDRs |
| `allowed_ips` | `0.0.0.0/0` | IPs allowed to reach EKS API — restrict before go-live |
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
| `eks_cluster_endpoint` | EKS API server endpoint (sensitive) |
| `eks_kubeconfig_command` | kubectl connect command |
| `oidc_provider_arn` | OIDC ARN for IRSA roles |

---

## Remote state

```
bucket: motg-terraform-state-us-east-1
key:    prod/terraform.tfstate
lock:   motg-terraform-locks (DynamoDB)
```
