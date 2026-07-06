# Fernbank & Co. — Book Store App

Frontend + backend implementation of the services in the `terraform-bookstore` project:

- `backend/product-service` — Node/Express, reads/writes the `products` table in Aurora.
  Deploys as the **Product Service (ECS Fargate)** box in the diagram.
- `backend/order-service` — Node/Express, verifies the Cognito JWT, writes the `orders`
  table, and publishes to SQS. Deploys as the **Order Service (ECS Fargate)** box.
- `frontend` — React (Vite) single-page app. Builds to static files for the
  **Amazon S3 (Static Website Hosting)** bucket, and talks to Cognito directly for
  Sign Up / Login / JWT, matching steps 1–4 in the diagram.

The **Order Processing Lambda** lives inside the `terraform-bookstore` project itself
(`lambda/order_processing/handler.py`) since Terraform owns and zips it directly.

## Request flow (matches the diagram)

1. Browser loads the static site from S3.
2. User signs up / logs in directly against the Cognito User Pool → gets a JWT.
3. Browser calls the ALB:
   - `GET /products` (no auth) → Product Service → Aurora.
   - `POST /orders` (`Authorization: Bearer <JWT>`) → Order Service → verifies JWT →
     writes `orders` row as `PENDING` → publishes to SQS.
4. SQS triggers the Order Processing Lambda, which updates the order to `PROCESSED`
   in Aurora.
5. The frontend's Order History view polls `GET /orders` and reflects the new status.

## 1. Deploy the infrastructure first

Follow `terraform-bookstore/README.md` to `terraform apply` the infrastructure. Grab these
outputs — you'll need them below:

```bash
terraform output ecr_product_service_repo_url
terraform output ecr_order_service_repo_url
terraform output aurora_cluster_endpoint
terraform output db_master_credentials_secret_arn
terraform output orders_queue_url
terraform output cognito_user_pool_id
terraform output cognito_user_pool_client_id
terraform output alb_dns_name
terraform output static_site_bucket_website_endpoint
```

## 2. Build & push the backend containers

Both services read DB credentials from environment variables. Pull the actual password out
of Secrets Manager at deploy time (or wire your ECS task definition to `secrets` referencing
the ARN directly — recommended for production instead of plain env vars):

```bash
aws secretsmanager get-secret-value \
  --secret-id <db_master_credentials_secret_arn> \
  --query SecretString --output text
```

```bash
aws ecr get-login-password --region <region> | \
  docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com

# Product Service
cd backend/product-service
docker build -t <ecr_product_service_repo_url>:latest .
docker push <ecr_product_service_repo_url>:latest

# Order Service
cd ../order-service
docker build -t <ecr_order_service_repo_url>:latest .
docker push <ecr_order_service_repo_url>:latest
```

Then update the ECS services (or just re-run `terraform apply` / force a new deployment)
so Fargate pulls the new images:

```bash
aws ecs update-service --cluster <ecs_cluster_name> --service <project>-<env>-product-service --force-new-deployment
aws ecs update-service --cluster <ecs_cluster_name> --service <project>-<env>-order-service --force-new-deployment
```

### Environment variables each service needs

`ecs.tf` in the Terraform project already injects all of these into the task definitions —
nothing to configure manually:

| Variable | product-service | order-service |
|---|---|---|
| `DB_HOST` | ✅ Aurora writer endpoint | ✅ Aurora writer endpoint |
| `DB_NAME` | ✅ | ✅ |
| `DB_USER` | ✅ master username | ✅ master username |
| `DB_PASSWORD` | ✅ via Secrets Manager (`secrets` block, never plaintext) | ✅ via Secrets Manager |
| `S3_BUCKET` | ✅ file storage bucket | — |
| `ORDERS_QUEUE_URL` | — | ✅ SQS orders queue URL |
| `COGNITO_USER_POOL_ID` | — | ✅ |
| `COGNITO_CLIENT_ID` | — | ✅ |

You only need to build and push the container images — the infrastructure wiring is done.

## 3. Build & deploy the frontend

```bash
cd frontend
cp .env.example .env
# edit .env with alb_dns_name, cognito_user_pool_id, cognito_user_pool_client_id

./deploy.sh <static_site_bucket_name>
```

Then open the URL from `terraform output static_site_bucket_website_endpoint`.

## Local development (optional)

Spin up a local MySQL to test the backend services without touching AWS:

```bash
docker run --name bookstore-mysql -e MYSQL_ROOT_PASSWORD=devpass \
  -e MYSQL_DATABASE=bookstore -p 3306:3306 -d mysql:8

cd backend/product-service
DB_HOST=localhost DB_USER=root DB_PASSWORD=devpass DB_NAME=bookstore npm install && npm run dev

cd ../order-service
DB_HOST=localhost DB_USER=root DB_PASSWORD=devpass DB_NAME=bookstore npm install && npm run dev
```

With no `COGNITO_USER_POOL_ID` set, `order-service` skips JWT verification and treats every
request as `dev-user` — handy for local testing, never do this in a deployed environment.

For the frontend, point `VITE_API_BASE_URL` at `http://localhost:8080` and run
`npm run dev` — but note `/products` and `/orders` won't both be reachable on one port
locally since the ALB is what merges them in AWS; run each service on its own port and
adjust `VITE_API_BASE_URL` per call, or just test against the deployed ALB.
