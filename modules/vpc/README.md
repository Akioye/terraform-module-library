# Module: vpc

Creates a production-grade AWS VPC with public and private subnets, an Internet Gateway, NAT Gateways, and VPC Flow Logs.

This is the foundation module — all other modules (`rds`, `eks`, `iam`) consume its outputs.

---

## Architecture

```
                        ┌─────────────────────────────────────┐
                        │              VPC (10.0.0.0/16)       │
  Internet              │                                       │
     │                  │  ┌─────────────┐  ┌─────────────┐   │
     │     ┌────────────┤  │ Public AZ-a │  │ Public AZ-b │   │
     ▼     │            │  │ 10.0.1.0/24 │  │ 10.0.2.0/24 │   │
  ┌─────┐  │ IGW        │  │   NAT GW    │  │  (NAT GW*)  │   │
  │ IGW │◄─┘            │  └──────┬──────┘  └──────┬──────┘   │
  └──┬──┘               │         │                 │           │
     │                  │  ┌──────▼──────┐  ┌──────▼──────┐   │
     └──────────────────┤  │Private AZ-a │  │Private AZ-b │   │
                        │  │ 10.0.11.0/24│  │10.0.12.0/24 │   │
                        │  │  EKS nodes  │  │  EKS nodes  │   │
                        │  │     RDS     │  │     RDS     │   │
                        │  └─────────────┘  └─────────────┘   │
                        └─────────────────────────────────────┘
* Second NAT GW only created when single_nat_gateway = false (prod)
```

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name = "motg"
  environment  = "dev"

  cidr_block          = "10.0.0.0/16"
  availability_zones  = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true    # false in prod
  enable_flow_logs   = false   # true in prod
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_name` | string | — | Project name prefix for all resources |
| `environment` | string | — | One of: dev, staging, prod |
| `cidr_block` | string | `10.0.0.0/16` | VPC CIDR block |
| `availability_zones` | list(string) | — | AZs to deploy into (1–3) |
| `public_subnet_cidrs` | list(string) | — | One CIDR per AZ for public subnets |
| `private_subnet_cidrs` | list(string) | — | One CIDR per AZ for private subnets |
| `enable_nat_gateway` | bool | `true` | Create NAT gateways for private subnets |
| `single_nat_gateway` | bool | `true` | Use one NAT GW (cost saving) vs one per AZ (HA) |
| `enable_flow_logs` | bool | `true` | Ship VPC flow logs to CloudWatch |
| `flow_logs_retention_days` | number | `30` | CloudWatch log retention period |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID — pass to all other modules |
| `vpc_cidr_block` | VPC CIDR block |
| `public_subnet_ids` | Public subnet IDs (load balancers, NAT GWs) |
| `private_subnet_ids` | Private subnet IDs (EKS nodes, RDS, apps) |
| `nat_public_ips` | EIPs on NAT GWs — whitelist in external firewalls |
| `internet_gateway_id` | IGW ID |
| `nat_gateway_ids` | NAT GW IDs |
| `private_route_table_ids` | Private route table IDs |
| `public_route_table_id` | Public route table ID |

## Environment differences

| Variable | dev | staging | prod |
|---|---|---|---|
| `single_nat_gateway` | `true` | `true` | `false` |
| `enable_flow_logs` | `false` | `true` | `true` |
| `flow_logs_retention_days` | 7 | 30 | 90 |
| AZ count | 1 | 2 | 2–3 |

## EKS subnet tagging

Public and private subnets are automatically tagged with the Kubernetes subnet discovery tags:
- Public: `kubernetes.io/role/elb = 1`
- Private: `kubernetes.io/role/internal-elb = 1`

These are required for the EKS module to provision load balancers correctly.
