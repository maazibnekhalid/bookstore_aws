############################
# General
############################

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used as a prefix for resources"
  type        = string
  default     = "bookstore"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

############################
# Networking
############################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to spread subnets across (2 recommended for HA)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (ALB)"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (ECS Fargate, Lambda)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDRs for isolated database subnets (Aurora)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway to save cost (set false for one-per-AZ HA)"
  type        = bool
  default     = true
}

############################
# ACM / TLS
############################

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the ALB HTTPS listener. Leave empty to deploy HTTP-only (not recommended for prod)."
  type        = string
  default     = ""
}

############################
# Cognito
############################

variable "cognito_domain_prefix" {
  description = "Unique prefix for the Cognito Hosted UI domain (must be globally unique)"
  type        = string
  default     = "bookstore-auth"
}

variable "callback_urls" {
  description = "Allowed OAuth callback URLs for the Cognito app client (e.g. the S3/CloudFront static site URL)"
  type        = list(string)
  default     = ["https://localhost:3000/callback"]
}

variable "logout_urls" {
  description = "Allowed OAuth logout URLs for the Cognito app client"
  type        = list(string)
  default     = ["https://localhost:3000/logout"]
}

############################
# ECS / Containers
############################

variable "product_service_image_tag" {
  description = "Image tag to deploy for the Product Service (image lives in the ECR repo created by this project)"
  type        = string
  default     = "latest"
}

variable "order_service_image_tag" {
  description = "Image tag to deploy for the Order Service"
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Port both services listen on inside the container"
  type        = number
  default     = 8080
}

variable "service_cpu" {
  description = "Fargate task vCPU units (256 = .25 vCPU)"
  type        = number
  default     = 256
}

variable "service_memory" {
  description = "Fargate task memory (MB)"
  type        = number
  default     = 512
}

variable "product_service_desired_count" {
  type    = number
  default = 2
}

variable "order_service_desired_count" {
  type    = number
  default = 2
}

############################
# Database (Aurora MySQL)
############################

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "bookstore"
}

variable "db_master_username" {
  description = "Aurora master username"
  type        = string
  default     = "bookstore_admin"
}

variable "db_instance_class" {
  description = "Instance class for Aurora writer/reader instances"
  type        = string
  default     = "db.t4g.medium"
}

variable "db_reader_count" {
  description = "Number of Aurora reader instances"
  type        = number
  default     = 2
}

variable "db_backup_retention_days" {
  type    = number
  default = 7
}

############################
# Lambda / SQS
############################

variable "lambda_runtime" {
  type    = string
  default = "python3.12"
}

variable "sqs_visibility_timeout" {
  description = "Should be >= 6x the Lambda function timeout"
  type        = number
  default     = 60
}

variable "lambda_timeout" {
  type    = number
  default = 10
}

############################
# CloudFront
############################

variable "cloudfront_domain_names" {
  description = "Alias domain(s) (CNAMEs) for the CloudFront distribution, e.g. [\"www.example.com\"]"
  type        = list(string)
  default     = []
}

variable "cloudfront_acm_certificate_arn" {
  description = "ACM certificate ARN for CloudFront. MUST be issued in us-east-1 regardless of aws_region, since CloudFront only accepts certs from that region. Leave empty to use the default *.cloudfront.net domain with no custom aliases."
  type        = string
  default     = ""
}

variable "cloudfront_price_class" {
  description = "PriceClass_All (all edge locations), PriceClass_200, or PriceClass_100 (cheapest, US/EU/Canada only)"
  type        = string
  default     = "PriceClass_100"
}

variable "restrict_alb_to_cloudfront" {
  description = "If true, the ALB security group only accepts inbound 80/443 from CloudFront's IP range instead of the whole internet"
  type        = bool
  default     = true
}

############################
# Misc
############################

variable "enable_cloudtrail" {
  description = "Whether to create an org/account CloudTrail trail"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  type    = number
  default = 30
}
