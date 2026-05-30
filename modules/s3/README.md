# Module: s3

Creates a production-hardened S3 bucket with versioning, AES256 or KMS encryption, full public access block, TLS-only bucket policy, optional lifecycle rules, and optional CORS.

---

## Usage

```hcl
module "app_uploads" {
  source = "../../modules/s3"

  project_name  = "motg"
  environment   = "dev"
  bucket_suffix = "uploads"

  enable_versioning = true
  force_destroy     = true   # dev only

  lifecycle_rules = [
    {
      id      = "expire-old-versions"
      enabled = true
      noncurrent_version_expiration_days = 30
    }
  ]
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_name` | string | — | Project prefix |
| `environment` | string | — | dev, staging, or prod |
| `bucket_suffix` | string | — | Appended after env (e.g. uploads, logs) |
| `enable_versioning` | bool | `true` | Enable versioning |
| `force_destroy` | bool | `false` | Allow destroy with objects — dev only |
| `kms_key_arn` | string | `null` | KMS key ARN for SSE-KMS (null = AES256) |
| `lifecycle_rules` | list(object) | `[]` | Lifecycle rule definitions |
| `cors_rules` | list(object) | `[]` | CORS rules for web-facing buckets |
| `additional_bucket_policy_statements` | list(any) | `[]` | Extra IAM statements for bucket policy |

## Outputs

| Name | Description |
|---|---|
| `bucket_id` | Bucket name |
| `bucket_arn` | Bucket ARN — use in IAM policies |
| `bucket_domain_name` | Domain name |
| `bucket_regional_domain_name` | Regional domain (preferred) |
| `bucket_region` | Bucket region |

## Environment differences

| Setting | dev | staging | prod |
|---|---|---|---|
| `force_destroy` | `true` | `false` | `false` |
| `enable_versioning` | `true` | `true` | `true` |
| `kms_key_arn` | null | null | KMS key ARN |
| Lifecycle noncurrent expiry | 30 days | 60 days | 90 days |
