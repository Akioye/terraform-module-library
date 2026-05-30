# Runbook

Day-2 operations guide. How to make changes safely, promote between environments, upgrade Kubernetes, and recover from common incidents.

---

## Making infrastructure changes

### The safe way — always

```
1. Make your change in modules/ or environments/
2. git checkout -b feat/your-change
3. git push && open a PR
4. CI runs terraform plan on all 3 environments
5. Review the plan output in the PR comment
6. Merge after plans pass
7. Apply environments in order: dev → staging → prod
```

Never apply directly from main without a PR. The plan output in CI is your safety net — it shows exactly what will change before anything touches real infrastructure.

---

## Promoting a module change

When you update a module (e.g. add a parameter to the VPC module):

```bash
# 1. Make the change in modules/vpc/
# 2. Test in dev first
cd environments/dev
terraform plan   # review the diff
terraform apply

# 3. Validate dev works
kubectl get nodes
aws rds describe-db-instances --db-instance-identifier motg-dev-db

# 4. Apply staging
cd environments/staging
terraform plan
terraform apply

# 5. Validate staging, then apply prod
cd environments/prod
terraform plan   # read every line carefully
terraform apply
```

---

## Adding a new S3 bucket

```hcl
# In environments/dev/main.tf, add:
module "s3_logs" {
  source = "../../modules/s3"

  project_name  = var.project_name
  environment   = var.environment
  bucket_suffix = "logs"

  enable_versioning = false
  force_destroy     = true

  lifecycle_rules = [
    {
      id              = "expire-logs"
      enabled         = true
      expiration_days = 30
    }
  ]
}
```

Add the same block to staging and prod `main.tf`, adjusting `force_destroy` and retention as needed. Open a PR — CI will plan all three environments.

---

## Scaling EKS nodes

Node counts are controlled by `node_desired_size`, `node_min_size`, `node_max_size` in each environment's `terraform.tfvars`.

The node group has `ignore_changes` on `desired_size` — this means the cluster autoscaler can scale nodes up and down without Terraform fighting it. Only `min` and `max` are enforced by Terraform.

To change the bounds:

```bash
# Edit environments/prod/terraform.tfvars
# node_min_size = 2
# node_max_size = 8

terraform plan   # verify only scaling config changes
terraform apply
```

---

## Upgrading Kubernetes version

EKS upgrades must be done one minor version at a time (1.28 → 1.29, not 1.28 → 1.30).

```bash
# 1. Check current version
aws eks describe-cluster --name motg-prod --query cluster.version

# 2. Update kubernetes_version in terraform.tfvars
# kubernetes_version = "1.30"

# 3. Plan — verify only the cluster version changes
terraform plan

# 4. Apply — control plane upgrades first (~10 min)
terraform apply

# 5. Update node group — nodes must match or be one version behind
# EKS managed node groups update automatically after cluster upgrade
# Verify nodes are on new version
kubectl get nodes
```

Always upgrade dev first, validate, then staging, then prod.

---

## Rotating database credentials

RDS credentials are passed as environment variables. To rotate:

```bash
# 1. Update the secret in AWS Secrets Manager (if using it)
# or prepare the new password

# 2. Apply with the new password
export TF_VAR_db_username=produser
export TF_VAR_db_password=newstrongpassword
terraform apply   # triggers a DB modification — brief interruption

# 3. Update GitHub Actions secrets
# Settings → Secrets → TF_VAR_DB_PASSWORD → Update
```

RDS password changes cause a brief DB restart. Schedule during low-traffic windows for prod.

---

## Recovering from a corrupted Terraform state

If state becomes corrupted or gets out of sync with real AWS resources:

```bash
# Option 1 — restore from S3 version
# Go to AWS Console → S3 → motg-terraform-state → dev/terraform.tfstate
# Restore a previous version

# Option 2 — remove a specific resource from state and re-import
terraform state rm module.vpc.aws_vpc.this
terraform import module.vpc.aws_vpc.this vpc-xxxxxxxx

# Option 3 — refresh state from real AWS resources
terraform refresh
```

Never manually edit the `.tfstate` file. Always use `terraform state` commands.

---

## Releasing a stuck DynamoDB lock

If a `terraform apply` crashes mid-run, it may leave a lock in DynamoDB that prevents future runs.

```bash
# See the lock
aws dynamodb get-item \
  --table-name motg-terraform-locks \
  --key '{"LockID": {"S": "motg-terraform-state-us-east-1/dev/terraform.tfstate"}}'

# Force unlock (only if you're sure no apply is running)
terraform force-unlock <LOCK_ID>
```

The `LOCK_ID` is shown in the error message when Terraform complains about a locked state.

---

## Viewing drift between state and real AWS

Drift happens when someone changes a resource directly in AWS console instead of through Terraform.

```bash
# Check for drift
terraform plan

# If plan shows unexpected changes, someone modified resources outside Terraform
# Option 1 — let Terraform reconcile (apply to match code)
terraform apply

# Option 2 — update code to match reality
# Edit the relevant .tf file, then plan again
```

Drift is why you should always make infrastructure changes through Terraform, never the console.

---

## Destroying an environment safely

```bash
# Dev — clean, no protection
cd environments/dev
terraform destroy

# Staging
cd environments/staging
terraform destroy   # takes a final RDS snapshot

# Prod — requires two steps
cd environments/prod

# Step 1: disable deletion protection
# Edit main.tf: deletion_protection = false
terraform apply

# Step 2: empty S3 bucket first
aws s3 rm s3://motg-prod-uploads --recursive

# Step 3: destroy
terraform destroy
```

---

## Useful AWS CLI checks

```bash
# List all EKS clusters
aws eks list-clusters

# Check RDS instance status
aws rds describe-db-instances \
  --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]' \
  --output table

# List S3 buckets
aws s3 ls | grep motg

# Check NAT gateway status
aws ec2 describe-nat-gateways \
  --filter "Name=tag:Project,Values=motg" \
  --query 'NatGateways[*].[NatGatewayId,State]' \
  --output table

# Check VPC flow logs
aws logs describe-log-groups \
  --log-group-name-prefix /aws/vpc/flow-logs/motg
```
