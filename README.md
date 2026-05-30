# Terraform Module Library  

Production-grade, reusable Terraform modules for AWS infrastructure. Three fully isolated environments share the same module code with environment-specific variables — the pattern senior engineers actually use.

---

## Structure

```
terraform-module-library/
├── bootstrap/               # Run once: creates S3 + DynamoDB for remote state
├── modules/
│   ├── vpc/                 # VPC, subnets, IGW, NAT, route tables, flow logs
│   ├── iam/                 # Roles, policies, instance profiles
│   ├── s3/                  # Buckets, versioning, encryption, lifecycle
│   ├── rds/                 # RDS instance, subnet group, security group
│   └── eks/                 # EKS cluster, managed node groups, OIDC
├── environments/
│   ├── dev/                 # t3.micro, single AZ, no HA
│   ├── staging/             # t3.medium, multi-AZ, mirrors prod config
│   └── prod/                # r5.large, HA, deletion protection enabled
└── .github/
    └── workflows/
        └── terraform-plan.yml   # Plans all 3 envs on every PR
```

## Modules

| Module | What it creates |
|---|---|
| [`vpc`](./modules/vpc/) | VPC, public/private subnets, IGW, NAT GW, flow logs |
| [`iam`](./modules/iam/) | IAM roles, policies, instance profiles |
| [`s3`](./modules/s3/) | S3 bucket with versioning, encryption, lifecycle rules |
| [`rds`](./modules/rds/) | RDS instance, subnet group, parameter group, security group |
| [`eks`](./modules/eks/) | EKS cluster, managed node groups, OIDC provider |

## How environments differ

| Variable | dev | staging | prod |
|---|---|---|---|
| Instance class | `t3.micro` | `t3.medium` | `r5.large` |
| EKS node type | `t3.small` | `t3.medium` | `m5.large` |
| Multi-AZ | No | Yes | Yes |
| NAT gateways | 1 (shared) | 1 (shared) | 1 per AZ |
| Deletion protection | Off | Off | On |
| Flow logs | Off | On | On |

## Getting started

### 1. Bootstrap remote state (once)

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — set your project_name and aws_region
terraform init
terraform apply
```

### 2. Deploy an environment

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

### 3. CI — GitHub Actions

Every PR against `main` automatically runs `terraform plan` for all three environments and posts the results as a PR comment. No manual checks needed.

Required GitHub Secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`

## Remote state

All environments store state in the S3 bucket created by bootstrap, with DynamoDB locking to prevent concurrent applies.

| Environment | State key |
|---|---|
| dev | `dev/terraform.tfstate` |
| staging | `staging/terraform.tfstate` |
| prod | `prod/terraform.tfstate` |

## Design decisions

**Modules are source-pinned by git tag** — each environment references modules at a specific tag (`?ref=v1.0.0`), so changes to a module don't silently affect prod. Promote changes: tag → update dev ref → test → update staging → test → update prod.

**No Terraform workspaces** — workspaces share a backend and are easy to accidentally target. Separate directories per environment are explicit, auditable, and harder to misuse.

**`prevent_destroy` on state resources** — the S3 bucket and DynamoDB table can't be deleted by `terraform destroy`. Protects against accidents.

**Least-privilege IAM** — each module creates only the permissions it needs. No `*` actions, no wildcard resources unless genuinely required.
