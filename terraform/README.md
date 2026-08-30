# Terraform — `docker-compose-react-nodejs-postgres` on AWS ECS

Infrastructure-as-code for running the reference app on AWS Fargate behind an
Application Load Balancer, with PostgreSQL on RDS, three subnet tiers, NAT egress,
security groups, network ACLs and a WAF.

> **Nothing here is deployed.** These are definition files. No AWS resource exists until
> someone runs `terraform apply` with valid credentials. `terraform validate` and
> `terraform fmt` are offline operations and contact nothing.

---

## Architecture

```
                          Internet
                              │
                       ┌──────▼──────┐
                       │  WAFv2 ACL  │  rate limit, IP reputation,
                       └──────┬──────┘  common rules, bad inputs, SQLi
                              │
  ┌───────────────────────────▼──────────────────────────────┐  PUBLIC subnets
  │  Application Load Balancer          NAT Gateway(s)        │  (one per AZ)
  └───────────┬───────────────────────────────┬──────────────┘
              │ /users/* /user/* /healthz     │ egress only
              │ → server        else → client │
  ┌───────────▼───────────────────────────────┴──────────────┐  APP subnets
  │  ECS Fargate                                              │  (private)
  │    server  (Node/Express + Prisma)   client (Vite)        │
  │    autoscaled on CPU + memory                             │
  └───────────┬───────────────────────────────────────────────┘
              │ :5432
  ┌───────────▼───────────────────────────────────────────────┐  DATA subnets
  │  RDS PostgreSQL — encrypted, private, no route to internet │  (isolated)
  └────────────────────────────────────────────────────────────┘
```

Three tiers, each with its own route table and NACL:

| Tier | Contains | Internet route |
|---|---|---|
| `public` | ALB, NAT gateways | Yes, via Internet Gateway |
| `app` | ECS tasks | Outbound only, via NAT |
| `data` | RDS | **None** — no default route at all |

The data tier having no default route is deliberate: RDS never needs to originate a
connection, and its absence means a compromised database cannot call out.

---

## What this creates

| Area | Resources |
|---|---|
| **Network** | VPC, 3 subnet tiers × N AZs, IGW, NAT gateway(s), route tables, 3 NACLs, S3 gateway endpoint, optional interface endpoints, VPC flow logs |
| **Security** | 3 security groups chained ALB → ECS → RDS, each referencing the previous group rather than a CIDR |
| **WAF** | WAFv2 regional ACL on the ALB: rate limit, IP reputation, common rule set, known bad inputs, SQLi, optional geo-block; logging with `authorization` and `cookie` redacted |
| **Database** | RDS PostgreSQL, encrypted gp3, private, parameter group forcing SSL, generated password in Secrets Manager, optional Multi-AZ and Performance Insights |
| **Registry** | 2 ECR repositories with scan-on-push and lifecycle policies |
| **Compute** | ECS cluster, ALB + 2 target groups + listener rules, 2 Fargate services, task definitions, CPU/memory autoscaling, CloudWatch log groups, execution and task IAM roles |

---

## Layout

```
terraform/
├── bootstrap/              # S3 state bucket — run once per account
├── modules/
│   ├── network/            # VPC, subnets, NAT, route tables, NACLs, endpoints, flow logs
│   ├── security/           # the three security groups
│   ├── waf/                # WAFv2 web ACL + logging
│   ├── database/           # RDS + Secrets Manager
│   ├── ecr/                # repositories + lifecycle policies
│   ├── compute/            # ECS, ALB, IAM, autoscaling
│   └── stack/              # composes all of the above
└── envs/
    ├── dev/                # thin wrapper + terraform.tfvars
    ├── staging/
    └── prod/
```

Each environment is a thin wrapper around `modules/stack`. Everything that differs between
environments lives in `terraform.tfvars`, so dev, staging and prod stay structurally
identical and only differ in sizing and guard rails.

---

## Environment differences

| | dev | staging | prod |
|---|---|---|---|
| VPC CIDR | `10.10.0.0/16` | `10.20.0.0/16` | `10.30.0.0/16` |
| AZs | 2 | 2 | 3 |
| NAT gateways | 1 (shared) | 1 (shared) | one per AZ |
| Interface endpoints | no | no | yes |
| Server tasks | 1 → 2 | 2 → 4 | 3 → 12 |
| Server size | 256/512 | 512/1024 | 1024/2048 |
| RDS | `t4g.micro` | `t4g.small` | `t4g.medium`, **Multi-AZ** |
| Backups | 1 day | 7 days | 30 days |
| WAF | count mode | blocking | blocking |
| ECS Exec | enabled | enabled | **disabled** |
| Deletion protection | off | on | on |
| Log retention | 7 days | 30 days | 90 days |
| Image tag | `:latest` | `:latest` | pinned `:v1.0.0` |

Two of those are worth calling out:

- **`waf_count_mode = true` in dev.** Managed rule groups count matches instead of blocking.
  Run a new environment this way for a few days, review the sampled requests, add exclusions
  for anything legitimate, then switch to blocking. Turning managed rules straight on in
  front of real users is how you discover they block your own upload endpoint.
- **prod pins an immutable image tag.** `:latest` makes rollback guesswork and lets two
  tasks silently run different code.

---

## Using it

### 1. State backend — once per account

```bash
cd terraform/bootstrap
terraform init
terraform apply -var 'bucket_name=your-globally-unique-tfstate-bucket'
```

Then uncomment the backend block in `envs/<env>/backend.tf` with the printed values and run
`terraform init -migrate-state`.

Until you do this, state is a local file. That is fine for a solo experiment and wrong for a
team — two people applying against local state will silently diverge.

### 2. Create the registries

The task definitions reference images that must already exist, so ECR comes first:

```bash
cd terraform/envs/dev
terraform init
terraform apply -target=module.stack.module.ecr
terraform output ecr_repository_urls
```

### 3. Build and push the images

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGION=ap-south-1
REPO=$ACCOUNT.dkr.ecr.$REGION.amazonaws.com

aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin $REPO

cd /path/to/docker-compose-react-nodejs-postgres

docker build -t $REPO/crudapp-dev/server:latest ./server
docker push $REPO/crudapp-dev/server:latest

# The client bakes its API URL in at BUILD time, not run time — see the note below.
docker build --build-arg VITE_SERVER_URL=http://<alb-dns-name> \
  -t $REPO/crudapp-dev/client:latest ./client
docker push $REPO/crudapp-dev/client:latest
```

### 4. Fill in the image URIs and apply

Replace `<account-id>` in `envs/dev/terraform.tfvars`, then:

```bash
terraform plan     # read this before applying — it creates billable resources
terraform apply
terraform output application_url
```

---

## Two ordering problems, and how to handle them

**The client's API URL is baked in at build time.** Vite substitutes `VITE_SERVER_URL` during
`npm run build`, so the image must know the ALB hostname before it is built — but the ALB
does not exist until after apply. Options, in order of preference:

1. Point a domain at the ALB with a Route 53 alias and build against that stable name. This
   is the only option that survives a load balancer replacement.
2. Apply once, take `terraform output alb_dns_name`, rebuild the client with it, push, and
   force a new deployment.
3. Serve the API under the same origin so a relative `/api` path works and no build-time URL
   is needed. This needs a small change to the client's fetch calls.

**Images must exist before the services start.** Hence the `-target=...ecr` step. Without it
the first apply creates services whose tasks fail to pull and crash-loop until you push.

---

## Deviations from `docker-compose.yml`

The compose file is not production-shaped, and two things were changed deliberately:

| compose | here | why |
|---|---|---|
| `prisma migrate reset --force` | `prisma migrate deploy` | `reset` **drops and reseeds the database on every container start**. On a service with 3 tasks that means repeatedly wiping the database. `deploy` applies pending migrations without destroying anything. |
| `.env` file with plaintext password | Secrets Manager, injected via the task definition's `secrets` block | The password is generated by Terraform, never written to a file, and never appears in the task definition or in `docker inspect`. |

`ENABLE_DEBUG_ROUTES` is **not** set anywhere here. That route throws on purpose and has no
business in a deployed environment.

---

## Security decisions

- **Security groups reference each other, not CIDRs.** `rds` accepts 5432 only from the `ecs`
  group; `ecs` accepts traffic only from the `alb` group. The rules stay correct when subnets
  change, and nothing in the app tier is reachable except through the load balancer.
- **The RDS security group has no egress rule at all.** It never needs to originate a
  connection.
- **NACLs duplicate the tier boundaries.** Security groups are stateful and are the primary
  control; NACLs are stateless and coarse, and exist so a loosened security group cannot
  open a tier boundary on its own.
- **Secrets are scoped.** The execution role can read exactly one secret ARN, not
  `secretsmanager:*`.
- **Execution and task roles are separate.** The execution role pulls images and reads the
  secret and is used by the ECS agent; the container itself runs under the task role, which
  is empty by default.
- **WAF logs redact `authorization` and `cookie`**, so a blocked request never writes
  credentials into CloudWatch.
- **Flow logs are on** for every VPC — the only way to answer "was that connection even
  attempted?" after the fact.

### What is deliberately left for you

- **`certificate_arn` is empty in all three environments.** Without it the ALB serves plain
  HTTP, which means credentials and session data cross the internet in the clear. Issue an
  ACM certificate in the same region and set it before any environment carries real traffic.
  Set it, and `:80` becomes a 301 redirect to `:443` automatically.
- **`alb_ingress_cidrs` defaults to `0.0.0.0/0`.** Correct for a public app; narrow it for an
  internal one.
- **No Route 53 record, no domain.** The ALB DNS name works but is ugly and not stable across
  a replacement.
- **No CI/CD.** No pipeline builds or pushes images.
- **No alarms.** CloudWatch alarms on 5xx rate, task count and RDS CPU are an obvious next
  step — or point `otel_exporter_endpoint` at a collector and alert in SigNoz instead.

---

## Cost

Rough order of magnitude for `ap-south-1`, excluding data transfer. **Verify with the AWS
Pricing Calculator before committing** — these move, and they vary by region.

| | dev | prod |
|---|---|---|
| NAT gateway | ~$32 (1) | ~$96 (3) |
| ALB | ~$18 | ~$20 |
| Fargate | ~$15 | ~$90 |
| RDS | ~$13 | ~$100 (Multi-AZ) |
| Interface endpoints | — | ~$105 (5 × 3 AZ) |
| Logs, WAF, misc | ~$5 | ~$25 |
| **Approx / month** | **~$80** | **~$440** |

The two biggest levers are NAT gateways and interface endpoints. `single_nat_gateway = true`
and `enable_interface_endpoints = false` roughly halve the prod figure at the cost of AZ
resilience and private AWS API access.

**Destroying dev is meant to work**: it sets `protect_resources = false`, which disables RDS
deletion protection, skips the final snapshot, and lets ECR delete repositories that still
contain images. Staging and prod deliberately refuse to be destroyed until you flip that.

---

## Adapting it

| You want | Change |
|---|---|
| A different region | `region` in each `terraform.tfvars` |
| More AZs | `az_count` (2–4) |
| A custom domain | Add an `aws_route53_record` alias to `alb_dns_name` / `alb_zone_id` |
| Aurora instead of RDS | Swap `aws_db_instance` for `aws_rds_cluster` in `modules/database` |
| Telemetry to SigNoz | Set `otel_exporter_endpoint` to a reachable collector; the app's SDK is entirely env-driven |
| Blue/green deploys | Add a CodeDeploy controller to the ECS services |

---

## Validating changes

All offline — no AWS credentials, no API calls, nothing created:

```bash
terraform fmt -recursive          # format
cd envs/dev
terraform init -backend=false     # download the provider plugin locally
terraform validate                # syntax and type check
```

`terraform plan` is the first command that talks to AWS, and it still creates nothing.
`terraform apply` is the only command that builds anything.
