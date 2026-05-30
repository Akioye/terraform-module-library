# Module: rds

Creates a production-grade RDS instance with a dedicated security group, subnet group, and parameter group. Supports Postgres and MySQL. Encryption enabled by default.

---

## Usage

```hcl
module "rds" {
  source = "../../modules/rds"

  project_name       = "motg"
  environment        = "dev"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  allowed_cidr_blocks = [module.vpc.vpc_cidr_block]

  engine                 = "postgres"
  engine_version         = "15.4"
  parameter_group_family = "postgres15"
  instance_class         = "db.t3.micro"

  db_name     = "motgdb"
  db_username = var.db_username
  db_password = var.db_password

  multi_az              = false   # true in staging/prod
  deletion_protection   = false   # true in prod
  skip_final_snapshot   = true    # false in prod
  backup_retention_days = 3
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_name` | string | — | Project prefix |
| `environment` | string | — | dev, staging, or prod |
| `vpc_id` | string | — | VPC ID from vpc module |
| `private_subnet_ids` | list(string) | — | Private subnet IDs from vpc module |
| `allowed_cidr_blocks` | list(string) | — | CIDRs allowed to connect |
| `engine` | string | `postgres` | DB engine |
| `engine_version` | string | `15.4` | Engine version |
| `parameter_group_family` | string | `postgres15` | Parameter group family |
| `instance_class` | string | `db.t3.micro` | Instance type |
| `allocated_storage` | number | `20` | Initial storage in GB |
| `max_allocated_storage` | number | `100` | Autoscaling upper limit in GB |
| `db_name` | string | — | Default database name |
| `db_username` | string | — | Master username (sensitive) |
| `db_password` | string | — | Master password (sensitive) |
| `db_port` | number | `5432` | Database port |
| `multi_az` | bool | `false` | Enable Multi-AZ standby |
| `backup_retention_days` | number | `7` | Days to keep automated backups |
| `skip_final_snapshot` | bool | `false` | Skip final snapshot on destroy |
| `deletion_protection` | bool | `false` | Block accidental deletion |
| `enable_enhanced_monitoring` | bool | `false` | Enable 1-min Enhanced Monitoring |
| `enable_performance_insights` | bool | `false` | Enable Performance Insights |

## Outputs

| Name | Description |
|---|---|
| `db_endpoint` | `host:port` — use in DATABASE_URL |
| `db_host` | Hostname only |
| `db_port` | Port |
| `db_name` | Database name |
| `db_username` | Master username |
| `security_group_id` | RDS security group ID |
| `db_instance_id` | RDS instance identifier |
| `db_instance_arn` | RDS instance ARN |

## Environment differences

| Variable | dev | staging | prod |
|---|---|---|---|
| `instance_class` | `db.t3.micro` | `db.t3.medium` | `db.r5.large` |
| `multi_az` | `false` | `true` | `true` |
| `deletion_protection` | `false` | `false` | `true` |
| `skip_final_snapshot` | `true` | `false` | `false` |
| `backup_retention_days` | `3` | `7` | `14` |
| `enable_performance_insights` | `false` | `true` | `true` |

## Security notes

- DB is deployed in private subnets only — never publicly accessible
- Storage encrypted at rest using AES256
- Password should come from AWS Secrets Manager in production, passed via `var.db_password`
- Security group restricts inbound to only the VPC CIDR (or tighter if you pass subnet CIDRs)
