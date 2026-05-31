# Terraform Module Library

> Built by Toby Akioye · [github.com/Akioye/terraform-module-library](https://github.com/Akioye/terraform-module-library)

---

## What is this?

This project is a **production-grade cloud infrastructure library** built on AWS using Terraform.

In plain terms — instead of manually clicking around in AWS to create servers, databases, and networks, everything here is written as code. You run one command and the entire infrastructure builds itself. You run another command and it tears itself down cleanly.

This is how serious engineering teams manage infrastructure at scale.

---

## What problem does it solve?

Most engineers set up cloud infrastructure manually — logging into AWS, clicking buttons, hoping they remember what they did. That approach breaks down fast:

- No record of what was created or why
- Can't reproduce it reliably
- One wrong click can take down production
- No way to test changes safely before they go live

This project solves all of that. Every server, database, network, and permission is defined in code, version controlled, automatically tested, and fully reproducible.

---
### Architectural Diagram
<p align="center">
    <img src="terraform-architecture-diagram.html" width="700" alt="project-architecture-diagram.png"/>
  </a>
</p>

---

## What's inside

### 5 reusable modules

Think of these as blueprints. Write once, use everywhere.

| Module | What it builds |
|---|---|
| `vpc` | The network — like the walls and rooms of a building |
| `iam` | Permissions — who is allowed to do what |
| `s3` | File storage — secure buckets for uploads, logs, backups |
| `rds` | The database — Postgres, encrypted, backed up automatically |
| `eks` | A Kubernetes cluster — where applications run |

### 3 isolated environments

The same blueprints are used three times with different settings:

| Environment | Purpose | Size |
|---|---|---|
| `dev` | Where you build and test. Break things here, not in prod | Small + cheap |
| `staging` | Rehearsal — looks exactly like prod but not live | Medium |
| `prod` | The real thing. Tightest security, deletion protection on | Reliable |

### Automated quality control (CI)

Every time a code change is proposed, the system automatically:
1. Checks if it would work in dev
2. Checks if it would work in staging
3. Checks if it would work in prod
4. Blocks the change from going through if any check fails

No human has to manually verify anything. The system does it in under 30 seconds.

---

## How it works in practice

```
Engineer makes a change
        ↓
Opens a Pull Request (proposes the change)
        ↓
System automatically tests all 3 environments in parallel
        ↓
All pass? → Change is allowed through
Any fail? → Change is blocked until fixed
        ↓
Engineer applies the change manually
dev → staging → prod
```

---

## Live proof

The CI pipeline is active on this repo. Every PR triggers real AWS validation across all three environments. You can see the results in the Actions tab.

---

## Tech stack

| Tool | What it does |
|---|---|
| Terraform | Writes infrastructure as code |
| AWS | The cloud platform everything runs on |
| S3 + DynamoDB | Stores and locks infrastructure state |
| GitHub Actions | Runs automatic checks on every code change |
| EKS | Managed Kubernetes for running applications |
| RDS | Managed Postgres database. |

---

## Project structure

```
terraform-module-library/
│
├── bootstrap/          → Creates the state storage system (run once)
├── modules/            → The 5 reusable blueprints
│   ├── vpc/
│   ├── iam/
│   ├── s3/
│   ├── rds/
│   └── eks/
├── environments/       → Three environments using the same blueprints
│   ├── dev/
│   ├── staging/
│   └── prod/
├── .github/workflows/  → Automatic checks that run on every change
└── docs/               → Full documentation
```

---

## Documentation

| Doc | What it covers |
|---|---|
| [Architecture](./docs/architecture.md) | How everything connects, network layout, security design |
| [Getting Started](./docs/getting-started.md) | How to deploy this from scratch |
| [Runbook](./docs/runbook.md) | How to make changes, upgrades, and handle incidents |
| [CI Setup](./.github/SETUP.md) | How the automated checks are configured |

---

## Key design decisions

**Separate environments, not workspaces** — each environment lives in its own folder. Changes can't accidentally affect the wrong environment.

**Everything is code** — no manual AWS console clicks. Every resource is defined, versioned, and reviewable.

**CI blocks bad changes** — infrastructure changes go through the same review process as application code. Nothing reaches prod without passing automated checks first.

**Deletion protection on prod** — the production database cannot be accidentally deleted. It takes a deliberate two-step process to remove it.

**Secrets never in code** — database passwords and AWS credentials are passed as environment variables, never written into any file in the repo.
