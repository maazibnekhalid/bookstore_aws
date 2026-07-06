# ALB: only entry point from CloudFront when restricted, otherwise from the internet.
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Allow inbound HTTP/HTTPS from the internet"
  vpc_id      = aws_vpc.main.id

  # CloudFront only needs the active origin port. The managed CloudFront prefix
  # list has a high rule weight, so opening both 80 and 443 can exceed the
  # default security group rule quota.
  dynamic "ingress" {
    for_each = var.acm_certificate_arn == "" ? [1] : []
    content {
      description     = var.restrict_alb_to_cloudfront ? "HTTP from CloudFront" : "HTTP"
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = var.restrict_alb_to_cloudfront ? [] : ["0.0.0.0/0"]
      prefix_list_ids = var.restrict_alb_to_cloudfront ? [data.aws_ec2_managed_prefix_list.cloudfront[0].id] : []
    }
  }

  dynamic "ingress" {
    for_each = var.acm_certificate_arn != "" ? [1] : []
    content {
      description     = var.restrict_alb_to_cloudfront ? "HTTPS from CloudFront" : "HTTPS"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = var.restrict_alb_to_cloudfront ? [] : ["0.0.0.0/0"]
      prefix_list_ids = var.restrict_alb_to_cloudfront ? [data.aws_ec2_managed_prefix_list.cloudfront[0].id] : []
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-alb-sg" }
}

# ECS services (Product Service, Order Service): only reachable from ALB.
resource "aws_security_group" "ecs_service" {
  name        = "${local.name}-ecs-service-sg"
  description = "Allow traffic from ALB to ECS Fargate tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Service to service"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-ecs-service-sg" }
}

# Lambda (Order Processing): private, egress only.
resource "aws_security_group" "lambda" {
  name        = "${local.name}-lambda-sg"
  description = "Order processing Lambda - egress only"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-lambda-sg" }
}

# Aurora: only reachable from ECS services and the Lambda function.
resource "aws_security_group" "aurora" {
  name        = "${local.name}-aurora-sg"
  description = "Allow MySQL from ECS services and order-processing Lambda only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From ECS services"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service.id]
  }

  ingress {
    description     = "From order-processing Lambda"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-aurora-sg" }
}
