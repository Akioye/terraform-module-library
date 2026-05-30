# Bootstrap

Creates the S3 bucket and DynamoDB table that store and lock Terraform state for all environments.

**Run this exactly once.** After that, all environments (`dev`, `staging`, `prod`) reference this bucket automatically via their `backend.tf`.

---

## Prerequisites

- AWS CLI configured (`aws configure`) with a user that has permission to create S3 buckets and DynamoDB tables.
- Terraform >= 1.6.0 installed.

## Usage

```bash
cd bootstrap

# 1. Edit terraform.tfvars — set your project_name and aws_region
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# 2. Init — no backend yet, state is stored locally just for this run
terraform init

# 3. Plan
terraform plan

# 4. Apply — creates the S3 bucket + DynamoDB table
terraform apply
```

After apply, Terraform prints a `backend_config_snippet` output. Copy that into each environment's `backend.tf`, replacing `<ENV>` with `dev`, `staging`, or `prod`.

---

## What it creates

| Resource | Name pattern | Purpose |
|---|---|---|
| S3 bucket | `<project>-terraform-state-<region>` | Stores `.tfstate` files for all envs |
| S3 versioning | enabled | Recover from accidental state corruption |
| S3 encryption | AES256 | State files encrypted at rest |
| S3 public access block | all blocked | No accidental public exposure |
| S3 lifecycle rule | noncurrent versions expire after 90 days | Cost control |
| S3 bucket policy | deny non-TLS | State never transmitted unencrypted |
| DynamoDB table | `<project>-terraform-locks` | Prevents concurrent applies corrupting state |
| DynamoDB PITR | enabled | Point-in-time recovery on lock table |

## Why `prevent_destroy = true`?

Both the S3 bucket and DynamoDB table have `lifecycle { prevent_destroy = true }`. This means `terraform destroy` will refuse to delete them — a safeguard against accidentally wiping state for all environments. To remove them, you'd need to manually remove the lifecycle block first.

## IAM permissions required

The user or role running bootstrap needs at minimum:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:CreateBucket",
    "s3:PutBucketVersioning",
    "s3:PutEncryptionConfiguration",
    "s3:PutBucketPolicy",
    "s3:PutBucketPublicAccessBlock",
    "s3:PutLifecycleConfiguration",
    "dynamodb:CreateTable",
    "dynamodb:DescribeTable",
    "dynamodb:UpdateContinuousBackups"
  ],
  "Resource": "*"
}
```

---

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `aws_region` | string | `us-east-1` | Region to deploy the state backend |
| `project_name` | string | — | Prefix for all resource names |

## Outputs

| Name | Description |
|---|---|
| `state_bucket_name` | S3 bucket name — paste into environment backend configs |
| `state_bucket_arn` | ARN of the state bucket |
| `dynamodb_table_name` | DynamoDB table name — paste into environment backend configs |
| `dynamodb_table_arn` | ARN of the lock table |
| `backend_config_snippet` | Ready-to-paste backend block for environment configs |
