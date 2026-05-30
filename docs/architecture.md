# Architecture

A full walkthrough of how this infrastructure is designed, how the modules relate to each other, and why key decisions were made the way they were.

---

## High-level overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Account                              │
│                                                                 │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐          │
│  │     dev     │   │   staging   │   │    prod     │          │
│  │ 10.0.0.0/16 │   │ 10.1.0.0/16 │   │ 10.2.0.0/16 │          │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘          │
│         │                 │                  │                  │
│         └─────────────────┴──────────────────┘                 │
│                           │                                     │
│              ┌────────────▼────────────┐                       │
│              │   S3 + DynamoDB         │                       │
│              │   Remote State Backend  │                       │
│              │   (bootstrap)           │                       │
│              └─────────────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

Each environment is fully isolated — its own VPC, its own subnets, its own EKS cluster and RDS instance. All three share one remote state backend created by bootstrap.

---

## Module dependency map

```
bootstrap
  └── creates S3 + DynamoDB (used by all environments)

vpc
  ├── outputs: vpc_id, private_subnet_ids, public_subnet_ids
  ├── consumed by: rds, eks
  └── no module dependencies

iam
  ├── outputs: role_arn, instance_profile_arn
  ├── consumed by: eks (node role), rds (monitoring role)
  └── no module dependencies

s3
  ├── outputs: bucket_id, bucket_arn
  └── no module dependencies

rds
  ├── inputs from vpc: vpc_id, private_subnet_ids
  ├── inputs from iam: monitoring_role_arn
  └── outputs: db_endpoint, db_name, security_group_id

eks
  ├── inputs from vpc: vpc_id, private_subnet_ids, public_subnet_ids
  ├── outputs: cluster_name, cluster_endpoint, oidc_provider_arn
  └── oidc_provider_arn → used by iam module for IRSA roles
```

**Build order matters.** When applying an environment for the first time:

```
1. vpc        — foundation, no dependencies
2. iam        — roles needed by eks and rds
3. s3         — standalone, no dependencies
4. rds        — needs vpc outputs
5. eks        — needs vpc outputs, creates OIDC
6. irsa roles — needs eks OIDC output (post-cluster)
```

Terraform resolves this automatically via the dependency graph. You just run `terraform apply` and it figures out the order.

---

## Network architecture

```
                           Internet
                               │
                        ┌──────▼──────┐
                        │     IGW     │
                        └──────┬──────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
   ┌──────▼──────┐             │             ┌──────▼──────┐
   │  Public     │             │             │  Public     │
   │  AZ-a       │             │             │  AZ-b       │
   │  NAT GW     │             │             │  NAT GW*    │
   └──────┬──────┘             │             └──────┬──────┘
          │                    │                    │
   ┌──────▼──────┐             │             ┌──────▼──────┐
   │  Private    │             │             │  Private    │
   │  AZ-a       │             │             │  AZ-b       │
   │  EKS nodes  │             │             │  EKS nodes  │
   │  RDS        │             │             │  RDS standby│
   └─────────────┘             │             └─────────────┘

* Second NAT GW only in prod (single_nat_gateway = false)
```

### Subnet CIDR allocation

| Environment | VPC | Public subnets | Private subnets |
|---|---|---|---|
| dev | `10.0.0.0/16` | `10.0.1-2.0/24` | `10.0.11-12.0/24` |
| staging | `10.1.0.0/16` | `10.1.1-2.0/24` | `10.1.11-12.0/24` |
| prod | `10.2.0.0/16` | `10.2.1-2.0/24` | `10.2.11-12.0/24` |

Non-overlapping CIDRs across environments means you can VPC peer them in future without conflicts.

---

## EKS architecture

```
┌──────────────────────────────────────────────────┐
│              EKS Control Plane                   │
│  (AWS managed — API server, etcd, scheduler)     │
│  KMS-encrypted secrets                           │
│  CloudWatch logs: api/audit/auth/cm/scheduler    │
└────────────────────┬─────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
┌───────▼──────┐     │     ┌──────▼───────┐
│ Managed Node │     │     │ Managed Node │
│ Group AZ-a   │     │     │ Group AZ-b   │
│ Private subnet│     │     │ Private subnet│
└──────────────┘     │     └──────────────┘
                     │
          ┌──────────▼──────────┐
          │   OIDC Provider     │
          │                     │
          │  Pod → IAM Role     │
          │  (IRSA)             │
          └─────────────────────┘
```

### IRSA (IAM Roles for Service Accounts)

IRSA lets individual pods assume IAM roles without static credentials. The OIDC provider is the bridge between Kubernetes service accounts and AWS IAM.

```
Pod (service account: app-sa)
  └── OIDC token → AWS STS
        └── AssumeRoleWithWebIdentity
              └── IAM Role (s3:GetObject on uploads bucket)
                    └── Pod gets temporary AWS credentials
```

No EC2 instance role needed. No credentials in environment variables. Each pod gets exactly the permissions it needs and nothing more.

---

## Remote state design

```
┌─────────────────────────────────────────┐
│   S3 Bucket: motg-terraform-state-*    │
│                                         │
│   dev/terraform.tfstate                 │
│   staging/terraform.tfstate             │
│   prod/terraform.tfstate                │
│                                         │
│   Versioning: enabled                   │
│   Encryption: AES256                    │
│   Public access: blocked                │
│   TLS only: enforced via bucket policy  │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│   DynamoDB: motg-terraform-locks        │
│                                         │
│   LockID (partition key)                │
│   PAY_PER_REQUEST billing               │
│   PITR: enabled                         │
└─────────────────────────────────────────┘
```

Each environment has its own state key. Locks are per-key — two people can apply dev and staging simultaneously without blocking each other. Only concurrent applies to the same environment are blocked.

---

## Security design

### Layers of protection

| Layer | What it does |
|---|---|
| VPC | All workloads in private subnets. No direct internet access to nodes or DB |
| Security groups | RDS only accepts connections from within the VPC CIDR. EKS nodes only accept traffic from the control plane |
| IAM | Least privilege per role. No wildcard actions. IRSA for pod-level permissions |
| Encryption | EKS secrets encrypted with KMS. RDS storage encrypted at rest. S3 encrypted with AES256. State bucket encrypted |
| TLS | S3 bucket policy denies all non-TLS requests. RDS connections over SSL |
| Deletion protection | Prod RDS cannot be deleted without a deliberate two-step process |
| State protection | `prevent_destroy` on S3 and DynamoDB — state backend cannot be accidentally destroyed |

### What `publicly_accessible = false` on RDS means

The RDS instance has no public endpoint. It can only be reached from within the VPC. To connect from your laptop you need either a bastion host, AWS SSM Session Manager port forwarding, or a VPN into the VPC.

---

## Environment promotion flow

```
feature branch
      │
      ▼
   PR opened
      │
      ▼
GitHub Actions: plan dev + staging + prod (parallel)
      │
      ▼
 All plans pass
      │
      ▼
  Merge to main
      │
   ┌──▼──┐
   │ dev │ ← apply manually, test
   └──┬──┘
      │ validated
   ┌──▼──────┐
   │ staging │ ← apply manually, test
   └──┬──────┘
      │ validated
   ┌──▼────┐
   │ prod  │ ← apply manually, review plan output first
   └───────┘
```

CI never applies — it only plans. Applies are always a deliberate human action.

---

## Cost profile (approximate, us-east-1)

| Resource | dev/month | staging/month | prod/month |
|---|---|---|---|
| NAT Gateway | ~$32 | ~$32 | ~$64 (2x) |
| EKS control plane | $72 | $72 | $72 |
| EKS nodes (t3.micro SPOT) | ~$3 | ~$5 | ~$10 (ON_DEMAND) |
| RDS db.t3.micro | ~$13 | ~$13 | ~$13 |
| S3 + misc | ~$1 | ~$1 | ~$2 |
| **Total** | **~$121** | **~$123** | **~$161** |

EKS control plane at $72/month is the biggest fixed cost. Destroy environments when not in use to avoid unnecessary charges.
