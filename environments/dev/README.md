# Environment: dev

The development environment. Lowest cost, fastest teardown. Used for active development and testing module changes before promoting to staging.

---

## What it creates

| Resource | Config |
|---|---|
| VPC | `10.0.0.0/16` · 2 public + 2 private subnets · 1 NAT gateway |
| EKS | `t3.micro` · SPOT nodes · 1 desired · 2 max |
| RDS | `db.t3.micro` · Postgres 15.4 · no Multi-AZ |
| S3 | Uploads bucket · versioning on · force destroy on |
| IAM | EKS node role · RDS monitoring role |

---

## Key dev-only settings

- `single_nat_gateway = true` — one shared NAT saves ~$32/month vs one per AZ
- `node_capacity_type = "SPOT"` — spot instances cut EKS node cost by up to 70%
- `force_destroy = true` on S3 — allows clean `terraform destroy` without manually emptying the bucket
- `skip_final_snapshot = true` on RDS — no snapshot taken on destroy, clean teardown
- `deletion_protection = false` — RDS can be destroyed freely
- `enable_flow_logs = false` — skips CloudWatch flow log cost in dev
- `backup_retention_days = 3` — minimum backup window

---

## Usage

```bash
cd environments/dev

# First time only
terraform init

# See what will be created
terraform plan

# Apply
terraform apply

# Connect to the cluster after apply
aws eks update-kubeconfig --name motg-dev --region us-east-1
kubectl get nodes

# Tear down completely
terraform destroy
```

---

## Passing secrets

Never put `db_username` or `db_password` in `terraform.tfvars`. Pass them as environment variables:

```bash
export TF_VAR_db_username=myuser
export TF_VAR_db_password=mypassword
terraform apply
```

---

## Inputs

| Name | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `project_name` | `motg` | Project prefix |
| `environment` | `dev` | Environment name |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `availability_zones` | `us-east-1a/b` | AZs to deploy into |
| `public_subnet_cidrs` | `10.0.1-2.0/24` | Public subnet CIDRs |
| `private_subnet_cidrs` | `10.0.11-12.0/24` | Private subnet CIDRs |
| `db_instance_class` | `db.t3.micro` | RDS instance size |
| `db_name` | `motgdb` | Database name |
| `db_username` | — | Master DB username (sensitive) |
| `db_password` | — | Master DB password (sensitive) |
| `kubernetes_version` | `1.29` | EKS Kubernetes version |
| `eks_node_instance_type` | `t3.micro` | EKS node instance type |

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

State is stored in S3 — configured in `backend.tf`:

```
bucket: motg-terraform-state-us-east-1
key:    dev/terraform.tfstate
lock:   motg-terraform-locks (DynamoDB)
```

Run bootstrap once before initialising this environment.
