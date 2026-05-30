# Getting Started

Step-by-step from zero to a fully deployed environment with CI running on every PR.

---

## Prerequisites

Before you start, make sure you have:

| Tool | Version | Install |
|---|---|---|
| Terraform | >= 1.6.0 | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | >= 2.0 | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| kubectl | >= 1.29 | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| Git | any | [git-scm.com](https://git-scm.com/) |

---

## Step 1 — Configure AWS credentials

```bash
aws configure
# AWS Access Key ID: <your key>
# AWS Secret Access Key: <your secret>
# Default region: us-east-1
# Default output format: json

# Verify it works
aws sts get-caller-identity
```

You should see your account ID and user ARN. If you get an error, your credentials are wrong.

---

## Step 2 — Clone the repo

```bash
git clone https://github.com/<your-username>/terraform-module-library.git
cd terraform-module-library
```

---

## Step 3 — Run bootstrap (once only)

Bootstrap creates the S3 bucket and DynamoDB table that store state for all environments. You only ever run this once.

```bash
cd bootstrap

# Review the defaults
cat terraform.tfvars

# Init — state is stored locally for this one run only
terraform init

# Plan
terraform plan

# Apply — this creates real AWS resources
terraform apply
```

After apply, note the outputs:

```bash
terraform output state_bucket_name    # e.g. motg-terraform-state-us-east-1
terraform output dynamodb_table_name  # e.g. motg-terraform-locks
```

These are already pre-filled in each environment's `backend.tf`. If your project name is different from `motg`, update them now.

```bash
cd ..
```

---

## Step 4 — Deploy the dev environment

```bash
cd environments/dev

# Set DB credentials as environment variables — never in tfvars
export TF_VAR_db_username=devuser
export TF_VAR_db_password=changeme123

# Init — connects to the S3 backend
terraform init

# Plan — review everything before applying
terraform plan

# Apply
terraform apply
```

This takes 15–20 minutes. EKS cluster creation is the slow part.

---

## Step 5 — Connect to your cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --name motg-dev --region us-east-1

# Verify nodes are ready
kubectl get nodes

# Check all system pods are running
kubectl get pods -n kube-system
```

You should see nodes in `Ready` state and all system pods running.

---

## Step 6 — Verify RDS is accessible from inside the VPC

RDS is private — no public endpoint. To test connectivity, run a pod inside the cluster:

```bash
kubectl run pg-client --rm -it \
  --image=postgres:15 \
  --restart=Never \
  -- psql -h <db_endpoint_from_outputs> -U devuser -d motgdb
```

Get the endpoint from:
```bash
terraform output db_endpoint
```

---

## Step 7 — Set up GitHub Actions CI

See the full setup guide at [../.github/SETUP.md](../.github/SETUP.md).

Short version:
1. Push the repo to GitHub
2. Add 5 secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `TF_VAR_DB_USERNAME`, `TF_VAR_DB_PASSWORD`
3. Set `All plans passed` as a required status check on the `main` branch
4. Open any PR — CI runs automatically

---

## Step 8 — Deploy staging and prod (when ready)

Same process as dev, different directory:

```bash
# Staging
cd environments/staging
export TF_VAR_db_username=staginguser
export TF_VAR_db_password=changeme456
terraform init
terraform plan
terraform apply

# Prod — review plan extra carefully
cd environments/prod
export TF_VAR_db_username=produser
export TF_VAR_db_password=strongpassword789
terraform init
terraform plan    # read every line
terraform apply
```

---

## Tearing down

```bash
# Dev — clean destroy, no snapshot taken
cd environments/dev
terraform destroy

# Staging/Prod — takes a final RDS snapshot first
cd environments/staging
terraform destroy
```

To destroy prod you must first disable deletion protection:

```bash
# Edit environments/prod/main.tf
# Change: deletion_protection = true
# To:     deletion_protection = false
terraform apply   # applies the change
terraform destroy # now destroy works
```

---

## Common errors

### `Error: Failed to get existing workspaces`
Backend not initialised yet. Run `terraform init` first, and make sure bootstrap has been applied.

### `Error: No valid credential sources found`
AWS credentials not configured. Run `aws configure` or set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.

### `Error: error creating EKS Node Group: InvalidParameterException`
Usually means the subnets don't have the right Kubernetes tags. The VPC module applies these automatically — check that the VPC was applied before EKS.

### `Error: timeout while waiting for state to become 'active'`
EKS cluster creation timed out. This is rare but happens. Run `terraform apply` again — it will pick up where it left off.

### Plan shows no changes but you expected changes
Check you're in the right environment directory and that your changes are saved. Also check the correct `terraform.tfvars` is present.

---

## Useful commands

```bash
# See all outputs for an environment
terraform output

# Target a single module (useful for debugging)
terraform plan -target=module.vpc
terraform apply -target=module.vpc

# See the full dependency graph
terraform graph | dot -Tsvg > graph.svg

# Format all .tf files
terraform fmt -recursive

# Validate all configs
terraform validate

# Show current state
terraform show

# List all resources in state
terraform state list

# Import an existing resource into state
terraform import module.vpc.aws_vpc.this vpc-xxxxxxxx
```
