# GitHub Actions Setup Guide

Everything you need to do once in GitHub to get the CI working.

---

## Step 1 — Create the GitHub repo

```bash
# In your terminal, inside the project folder
git init
git add .
git commit -m "feat: initial terraform module library"

# Create the repo on GitHub (via UI or gh CLI)
gh repo create terraform-module-library --public
git remote add origin https://github.com/<your-username>/terraform-module-library.git
git push -u origin main
```

---

## Step 2 — Add GitHub Secrets

Go to your repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these 5 secrets:

| Secret name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS access key ID |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret access key |
| `AWS_REGION` | `us-east-1` |
| `TF_VAR_DB_USERNAME` | Your database master username |
| `TF_VAR_DB_PASSWORD` | Your database master password |

> **Never** put these values in any `.tf` or `.tfvars` file. Secrets only live in GitHub.

---

## Step 3 — Set branch protection (makes CI required)

Go to your repo → **Settings** → **Branches** → **Add rule**

- Branch name pattern: `main`
- ✅ Require a pull request before merging
- ✅ Require status checks to pass before merging
  - Search for and add: **`All plans passed`**
- ✅ Require branches to be up to date before merging
- ✅ Do not allow bypassing the above settings

This means no code merges to main unless all 3 environment plans pass.

---

## Step 4 — How it works on every PR

1. You push a branch and open a PR against `main`
2. GitHub Actions triggers automatically
3. Three jobs run in parallel — `Plan (dev)`, `Plan (staging)`, `Plan (prod)`
4. Each job:
   - Runs `terraform init` against the S3 backend
   - Runs `terraform validate`
   - Runs `terraform plan` and captures the output
   - Posts the result as a PR comment (updates the same comment on re-runs)
5. A fourth job `All plans passed` checks all three succeeded
6. If any plan fails → PR is blocked from merging

---

## What the PR comment looks like

```
## Terraform Plan — dev

| Step    | Result     |
|---------|------------|
| Init    | ✅ success |
| Validate| ✅ success |
| Plan    | ✅ success |

📋 Show plan output   ← expandable

> 🔒 Pushed by @yourname · Run #12
```

One comment per environment, updated on every new commit to the PR.

---

## IAM permissions the CI user needs

The AWS user behind `AWS_ACCESS_KEY_ID` needs read permissions to plan.
Minimum policy for `terraform plan` (no write access needed for CI):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "eks:Describe*",
        "eks:List*",
        "rds:Describe*",
        "s3:GetObject",
        "s3:ListBucket",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "iam:Get*",
        "iam:List*"
      ],
      "Resource": "*"
    }
  ]
}
```

> For a portfolio project without a live AWS account, the plan will fail at the init/backend step but the workflow structure, comment posting, and matrix strategy are all real and visible to interviewers in the Actions tab.

---

## Triggering the workflow manually

The workflow only fires on PRs. To test it:

```bash
git checkout -b test/trigger-ci
# Make any small change — e.g. add a comment to any .tf file
git add .
git commit -m "test: trigger CI"
git push origin test/trigger-ci
# Open a PR against main on GitHub
```

Watch the Actions tab — all three jobs will start within seconds.
