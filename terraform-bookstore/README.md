# Simple Book Store Architecture (No API Gateway) — Terraform

Terraform implementation of the "Simple Book Store" architecture:

- **VPC** with public, private, and isolated database subnets across 2 AZs
- **Amazon Cognito** User Pool for authentication (JWT)
- **Application Load Balancer** routing `/products/*` → Product Service, `/orders/*` → Order Service
- **ECS Fargate**: Product Service + Order Service, in private subnets, behind the ALB
- **Amazon SQS** (Orders Queue + DLQ) → **Lambda** (Order Processing), consumed asynchronously
- **Amazon Aurora (MySQL-compatible)**: 1 writer + 2 reader instances in an isolated DB subnet
- **Amazon S3**: static website hosting, file/image storage, backups, CloudTrail audit logs
- **Amazon ECR**: repositories for the two service container images
- **Supporting services**: IAM (least privilege), CloudWatch (logs, metrics, alarms), CloudTrail (audit),
  S3 (backups), ECR (container images)

## File layout

```
versions.tf                 Terraform/provider setup
variables.tf                All input variables
vpc.tf                       VPC, subnets, IGW, NAT, route tables, flow logs
security_groups.tf          Least-privilege SGs between every tier
cognito.tf                   User Pool + Hosted UI + app client
alb.tf                       ALB, target groups, path-based listener rules
ecs.tf                       ECS cluster, task defs, Fargate services
ecr.tf                        Container image repositories
sqs_lambda.tf                Orders queue, DLQ, order-processing Lambda
rds.tf                        Aurora cluster (writer + readers), Secrets Manager
s3.tf                         Static site, file storage, backups, CloudTrail buckets
iam.tf                        Roles/policies for ECS, Lambda, flow logs
cloudwatch_cloudtrail.tf    Log groups, CloudTrail trail, basic alarms
outputs.tf                   Useful values after apply
lambda/order_processing/    Placeholder Lambda source (zipped automatically)
terraform.tfvars.example    Copy to terraform.tfvars and edit
```

## Prerequisites

1. [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
2. An AWS account + credentials configured (`aws configure` or environment variables)
3. Docker images for the Product Service and Order Service, pushed to the ECR repos this
   project creates (see step 3 below) — Terraform provisions the *infrastructure*, not your
   application code.

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set cognito_domain_prefix (must be globally unique),
# callback/logout URLs, and optionally an ACM cert ARN for HTTPS.

terraform init
terraform plan
terraform apply
```

### 1. First apply will create empty ECR repos

The ECS services reference `<repo_url>:latest` by default. On the very first `apply`, the
Fargate tasks will fail to start until you've pushed real images (steps below). This is
expected — re-run `terraform apply` (or just let ECS retry) once images exist.

### 2. Build & push your service images

```bash
aws ecr get-login-password --region <region> | \
  docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com

docker build -t <product-service-repo-url>:latest ./product-service
docker push <product-service-repo-url>:latest

docker build -t <order-service-repo-url>:latest ./order-service
docker push <order-service-repo-url>:latest
```

Repo URLs are in `terraform output ecr_product_service_repo_url` /
`ecr_order_service_repo_url`.

### 3. Deploy the static frontend

Upload your built static site (HTML/JS/CSS) to the bucket from
`terraform output static_site_bucket_name`, then invalidate CloudFront's cache so it
picks up the new files:

```bash
aws s3 sync ./frontend/build s3://<static-site-bucket>/
aws cloudfront create-invalidation --distribution-id $(terraform output -raw cloudfront_distribution_id) --paths '/*'
```

The site is served at `terraform output cloudfront_distribution_domain_name` (or your
custom domain, if you set `cloudfront_domain_names` / `cloudfront_acm_certificate_arn`).
The bucket itself is private — it's only reachable through CloudFront.

### 4. Order Processing Lambda

`lambda/order_processing/handler.py` consumes order-created messages from the Orders SQS
queue and marks the matching row `PROCESSED` in Aurora. It uses `pymysql`, which isn't part
of the Lambda Python runtime, so vendor it into the function folder **before** running
`terraform apply` (the `archive_file` data source zips whatever is in that directory):

```bash
pip install -r lambda/order_processing/requirements.txt \
  -t lambda/order_processing/ --platform manylinux2014_x86_64 --only-binary=:all:
```

Re-run `terraform apply` any time you change `handler.py` or update the vendored
dependencies — the archive hash changes and Terraform will redeploy the function.

## Notes & things to adjust before production

- **HTTPS**: leave `acm_certificate_arn` blank for a quick HTTP-only test, but set it to a
  real ACM certificate ARN before going to production — the ALB will refuse to answer HTTPS
  without one.
- **DB credentials**: a random master password is generated and stored in Secrets Manager
  (`db_master_credentials_secret_arn` output). Your services should fetch it at runtime
  rather than relying on hardcoded env vars.
- **Deletion protection**: `deletion_protection = true` on the Aurora cluster — you'll need
  to disable it manually before `terraform destroy` will succeed.
- **Cost**: 2 AZs + Aurora writer/2 readers + NAT Gateway is a real-money architecture, not
  free-tier. Reduce `db_reader_count` to 0 or 1, or use `single_nat_gateway = true`
  (default) to cut costs for a dev/test environment.
- **CloudFront**: this uses direct S3 static website hosting for simplicity. For production,
  put CloudFront in front of the S3 bucket for HTTPS, caching, and to keep the bucket private.
