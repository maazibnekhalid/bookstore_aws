output "vpc_id" {
  value = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "Point your domain / test in a browser at this address"
  value       = aws_lb.main.dns_name
}

output "static_site_bucket_name" {
  description = "Upload your frontend build here (aws s3 sync ./build s3://<this>)"
  value       = aws_s3_bucket.static_site.bucket
}

output "cloudfront_distribution_domain_name" {
  description = "Point your DNS (or browser, if no custom domain yet) here"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_id" {
  description = "Used for cache invalidations, e.g. aws cloudfront create-invalidation --distribution-id <this> --paths '/*'"
  value       = aws_cloudfront_distribution.main.id
}

output "file_storage_bucket" {
  value = aws_s3_bucket.file_storage.bucket
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.app.id
}

output "cognito_hosted_ui_domain" {
  value = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "ecr_product_service_repo_url" {
  value = aws_ecr_repository.product_service.repository_url
}

output "ecr_order_service_repo_url" {
  value = aws_ecr_repository.order_service.repository_url
}

output "orders_queue_url" {
  value = aws_sqs_queue.orders.url
}

output "order_processing_lambda_name" {
  value = aws_lambda_function.order_processing.function_name
}

output "aurora_cluster_endpoint" {
  description = "Writer endpoint"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_cluster_reader_endpoint" {
  description = "Load-balanced reader endpoint"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "db_master_credentials_secret_arn" {
  description = "Secrets Manager ARN holding the Aurora master username/password"
  value       = aws_secretsmanager_secret.db_master.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}
