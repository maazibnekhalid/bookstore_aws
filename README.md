# AWS Architecture

## AWS Architecture Diagram

<p align="center">
  <img src="./architecture%20diagram.png" alt="AWS Architecture Diagram" width="100%">
</p>

This project is a simple bookstore application deployed on AWS. It uses CloudFront and S3 for the frontend, an Application Load Balancer for API routing, ECS Fargate for the backend services, Aurora MySQL for persistent data, Cognito for users, and SQS plus Lambda for asynchronous order processing.

Current deployed entry point:

```text
https://maazibnekhalid.biz
```

## High-Level Design

```text
User browser
  |
  | HTTPS
  v
  ROUTE 53
  |
  | HTTPS
  v
Amazon CloudFront
  |-- default path /* ---------------------> Private S3 static-site bucket
  |
  |-- /products, /products/* --------------> Application Load Balancer
  |                                           |
  |                                           v
  |                                      ECS Product Service
  |                                           |
  |                                           v
  |                                      Aurora MySQL
  |
  |-- /orders, /orders/* ------------------> Application Load Balancer
                                              |
                                              v
                                         ECS Order Service
                                              |
                   +--------------------------+--------------------------+
                   |                                                     |
                   v                                                     v
              Aurora MySQL                                         Amazon SQS
                                                                         |
                                                                         v
                                                               Order Processing Lambda
                                                                         |
                                                                         v
                                                                    Aurora MySQL
```

## AWS Services

### Amazon CloudFront

CloudFront is the public HTTPS entry point for the application.

It has two origins:

- S3 origin for static frontend files such as `index.html`, JavaScript, CSS, and `error.html`.
- ALB origin for backend API calls.

CloudFront routing:

```text
/*                 -> S3 static frontend bucket
/products*         -> ALB -> Product Service
/orders*           -> ALB -> Order Service
```

The frontend calls APIs with relative paths such as `/products` and `/orders`, so the browser stays on HTTPS and avoids mixed-content errors.

### Amazon S3

This project uses multiple S3 buckets:

- `static_site`: private frontend bucket served only through CloudFront Origin Access Control.
- `file_storage`: private application-managed file/image storage bucket.
- `backups`: backup storage bucket with lifecycle expiration.
- `cloudtrail`: CloudTrail audit log bucket.

The static site bucket is not public. CloudFront is allowed to read objects from it through the bucket policy and Origin Access Control.

### Application Load Balancer

The ALB receives API traffic from CloudFront and routes it to ECS target groups.

Listener path rules:

```text
/products, /products/* -> Product Service target group
/orders, /orders/*     -> Order Service target group
```

The ALB health checks each service at:

```text
/health
```

In the current setup, the ALB origin is HTTP internally because `acm_certificate_arn` is blank. The user-facing connection is still HTTPS from the browser to CloudFront.

### Amazon ECS Fargate

ECS runs two backend services in private subnets:

- Product Service
- Order Service

Both services run as Fargate tasks using `awsvpc` networking. They do not receive public IP addresses. They are reachable only through the ALB security group.

### Product Service

The Product Service owns product catalog APIs.

Main routes:

```text
GET  /products
GET  /products/:id
POST /products
GET  /health
```

It connects to Aurora MySQL using:

- `DB_HOST`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD` from Secrets Manager

It reads and writes product records in the `products` table.

### Order Service

The Order Service owns authenticated order APIs.

Main routes:

```text
POST /orders
GET  /orders
GET  /orders/:id
GET  /health
```

All `/orders` routes require a Cognito JWT. The frontend sends the token in:

```text
Authorization: Bearer <id-token>
```

When a user places an order, the Order Service:

1. Validates the Cognito token.
2. Inserts the order into Aurora with status `PENDING`.
3. Sends an order-created message to SQS.
4. Returns the created order to the frontend.

### Amazon Cognito

Cognito provides user sign-up, sign-in, email verification, and JWT tokens.

The frontend uses:

- Cognito User Pool ID
- Cognito App Client ID

The Order Service validates the user's token before allowing order operations.

### Amazon Aurora MySQL

Aurora MySQL stores application data.

It runs in isolated database subnets. These subnets do not have a route to the internet gateway or NAT gateway.

The cluster has:

- 1 writer instance
- `db_reader_count` reader instances
- encrypted storage
- deletion protection enabled
- automated backups

Database access is allowed only from:

- ECS service security group on port `3306`
- Lambda security group on port `3306`

### AWS Secrets Manager

Secrets Manager stores the Aurora master credentials.

The ECS task execution role can read the database password for container startup. The Lambda execution role can also read it when processing SQS messages.

### Amazon SQS

SQS decouples order creation from order processing.

Queues:

- Orders Queue
- Orders Dead Letter Queue

The Order Service sends messages to the Orders Queue after inserting a pending order. If Lambda repeatedly fails to process a message, SQS eventually moves it to the DLQ after the configured max receive count.

### AWS Lambda

The Order Processing Lambda is triggered by SQS.

For each order message, it:

1. Reads the message body.
2. Extracts the order ID.
3. Connects to Aurora from private subnets.
4. Updates the matching order status to `PROCESSED`.

If processing fails, Lambda raises an error so SQS can retry the message.

### Amazon ECR

ECR stores Docker images for:

- Product Service
- Order Service

ECS pulls these images when starting or replacing Fargate tasks.

### CloudWatch

CloudWatch stores logs and metrics.

Log groups include:

- `/ecs/<name>/product-service`
- `/ecs/<name>/order-service`
- `/aws/lambda/<name>-order-processing`
- VPC flow logs

The infrastructure also includes metric alarms, such as ALB 5xx and Aurora CPU alarms.

### CloudTrail

CloudTrail records AWS account activity and writes audit logs to the CloudTrail S3 bucket.

### IAM

IAM roles are split by responsibility:

- ECS task execution role: pull images, write logs, read injected secrets.
- ECS task role: application permissions such as SQS send and S3 file-storage access.
- Lambda execution role: VPC access, SQS consume, logs, and Secrets Manager read.
- VPC flow logs role: write flow logs to CloudWatch Logs.

## Network Layout

The VPC is split across two Availability Zones.

```text
VPC
|
|-- Public subnets
|     |-- Application Load Balancer
|     |-- NAT Gateway
|     |-- Route to Internet Gateway
|
|-- Private subnets
|     |-- ECS Product Service tasks
|     |-- ECS Order Service tasks
|     |-- Order Processing Lambda ENIs
|     |-- Route to NAT Gateway for outbound AWS/API access
|
|-- Database subnets
      |-- Aurora MySQL writer and readers
      |-- No route to Internet Gateway
      |-- No route to NAT Gateway
```

### Subnet Purpose

Public subnets:

- Host internet-facing resources.
- Contain the ALB and NAT Gateway.
- Route `0.0.0.0/0` to the Internet Gateway.

Private subnets:

- Host ECS tasks and Lambda network interfaces.
- Do not expose public IPs.
- Route outbound internet traffic through NAT.

Database subnets:

- Host Aurora.
- Isolated from direct internet access.
- Only reachable through security group rules from ECS and Lambda.

## Security Group Rules

### ALB Security Group

Inbound:

- Allows only the active ALB origin port from CloudFront when `restrict_alb_to_cloudfront = true`.
- In the current HTTP-only ALB setup, this is port `80` from the CloudFront managed prefix list.

Outbound:

- Allows outbound traffic to ECS services.

### ECS Service Security Group

Inbound:

- Allows `container_port` from the ALB security group.
- Allows service-to-service traffic from itself on `container_port`.

Outbound:

- Allows outbound traffic for database access, SQS, S3, Secrets Manager, CloudWatch, and other required AWS APIs.

### Lambda Security Group

Inbound:

- None.

Outbound:

- Allows outbound traffic so Lambda can reach Aurora and AWS APIs.

### Aurora Security Group

Inbound:

- Allows MySQL port `3306` from the ECS service security group.
- Allows MySQL port `3306` from the Lambda security group.

Outbound:

- Allows outbound responses.

## Main Request Flows

### 1. Loading The Website

```text
Browser
  -> HTTPS request to CloudFront /
  -> CloudFront checks cache
  -> CloudFront fetches index.html/assets from private S3 if needed
  -> S3 allows read only because request comes from this CloudFront distribution
  -> Browser receives HTML, CSS, and JavaScript
```

Important detail: the S3 bucket is private. Users never access S3 directly.

### 2. Loading The Product Catalog

```text
Browser JavaScript
  -> GET https://d18exz05wo5dzc.cloudfront.net/products
  -> CloudFront matches /products*
  -> CloudFront forwards request to ALB
  -> ALB listener rule forwards to Product Service target group
  -> ECS Product Service receives GET /products
  -> Product Service queries Aurora products table
  -> Aurora returns product rows
  -> Product Service returns JSON
  -> ALB returns response to CloudFront
  -> CloudFront returns response to browser
```

The API cache behavior uses CloudFront's managed `CachingDisabled` policy, so API responses are forwarded rather than cached like static assets.

### 3. User Login

```text
Browser
  -> Uses Cognito User Pool and App Client
  -> User signs in or confirms account
  -> Cognito returns JWT tokens
  -> Frontend stores session locally through the Cognito client library
```

The backend does not handle passwords. It receives only Cognito JWTs on authenticated API calls.

### 4. Placing An Order

```text
Browser
  -> POST /orders with Authorization: Bearer <id-token>
  -> CloudFront forwards /orders* to ALB
  -> ALB forwards to Order Service target group
  -> ECS Order Service validates Cognito JWT
  -> Order Service writes order to Aurora with status PENDING
  -> Order Service sends order-created message to SQS
  -> Order Service returns 201 response to browser
```

The order is accepted quickly because the slow or retryable processing work is moved to SQS and Lambda.

### 5. Asynchronous Order Processing

```text
SQS Orders Queue
  -> Invokes Order Processing Lambda with a batch of messages
  -> Lambda reads DB credentials from Secrets Manager
  -> Lambda connects to Aurora from private subnets
  -> Lambda updates order status to PROCESSED
  -> Lambda completes successfully
  -> SQS deletes processed messages
```

If Lambda fails:

```text
Lambda error
  -> Message becomes visible again after visibility timeout
  -> SQS retries delivery
  -> After maxReceiveCount, message moves to DLQ
```

### 6. Viewing Order History

```text
Browser
  -> GET /orders with Authorization: Bearer <id-token>
  -> CloudFront forwards to ALB
  -> ALB forwards to Order Service
  -> Order Service validates token
  -> Order Service queries Aurora for orders matching the user's Cognito subject
  -> Order Service returns the user's order history
```

## Outbound Network Flow

ECS tasks and Lambda run in private subnets. They do not have public IP addresses.

When they need AWS APIs or public package endpoints at runtime, traffic flows like this:

```text
ECS task or Lambda ENI
  -> Private subnet route table
  -> NAT Gateway in public subnet
  -> Internet Gateway
  -> AWS public service endpoint or internet endpoint
```

Aurora does not use this path because database subnets are isolated.

## Deployment Flow

### Infrastructure

```text
Terraform
  -> Creates VPC, subnets, route tables, security groups
  -> Creates S3 buckets, CloudFront, ALB
  -> Creates ECR repositories
  -> Creates ECS services
  -> Creates Aurora, Secrets Manager, SQS, Lambda
  -> Creates IAM, CloudWatch, CloudTrail
```

### Backend Containers

```text
Developer machine or CI
  -> Build Docker image
  -> Push image to ECR
  -> ECS pulls image from ECR
  -> ECS starts/replaces Fargate tasks
```

### Frontend

```text
Developer machine or CI
  -> npm run build
  -> aws s3 sync dist/ s3://<static-site-bucket> --delete
  -> aws cloudfront create-invalidation --distribution-id <id> --paths /*
  -> Browser receives the new static build from CloudFront
```

## Why The Architecture Works This Way

- CloudFront gives one HTTPS hostname for both frontend and API paths.
- S3 stays private and only CloudFront can read static files.
- The ALB is not the public app URL; it is an origin behind CloudFront.
- ECS tasks are private and only reachable through the ALB.
- Aurora is isolated and only reachable by ECS and Lambda security groups.
- SQS decouples order creation from processing so the user does not wait for background work.
- Lambda processes orders asynchronously and retries failures through SQS.
- Secrets Manager keeps database passwords out of source code and container images.
- CloudWatch and CloudTrail provide operational logs, metrics, and audit history.

## Quick Troubleshooting Map

Frontend page does not load:

- Check CloudFront distribution.
- Check S3 static site bucket contents.
- Check CloudFront invalidation after deploying a new frontend build.

Catalog fails to load:

- Check browser console for `/products`.
- Check CloudFront `/products*` behavior.
- Check ALB listener rule for `/products`.
- Check Product Service ECS task health and logs.
- Check Aurora connectivity and `products` table.

Orders fail:

- Check Cognito token/session in the frontend.
- Check `/orders*` CloudFront behavior.
- Check ALB listener rule for `/orders`.
- Check Order Service ECS logs.
- Check Aurora order inserts.
- Check SQS permissions and queue messages.

Orders stay `PENDING`:

- Check SQS Orders Queue depth.
- Check Lambda logs.
- Check Lambda security group access to Aurora.
- Check Secrets Manager permissions.
- Check DLQ for failed messages.

