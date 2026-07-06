resource "aws_ecs_cluster" "main" {
  name = "${local.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${local.name}-cluster" }
}

resource "aws_cloudwatch_log_group" "product_service" {
  name              = "/ecs/${local.name}/product-service"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "order_service" {
  name              = "/ecs/${local.name}/order-service"
  retention_in_days = var.log_retention_days
}

############################
# Product Service
############################

resource "aws_ecs_task_definition" "product_service" {
  family                   = "${local.name}-product-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.service_cpu
  memory                   = var.service_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "product-service"
      image     = "${aws_ecr_repository.product_service.repository_url}:${var.product_service_image_tag}"
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      environment = [
        { name = "DB_HOST", value = aws_rds_cluster.aurora.endpoint },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USER", value = var.db_master_username },
        { name = "S3_BUCKET", value = aws_s3_bucket.file_storage.bucket },
      ]
      secrets = [
        { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db_master.arn}:password::" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.product_service.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "product-service"
        }
      }
    }
  ])

  tags = { Name = "${local.name}-product-service-task" }
}

resource "aws_ecs_service" "product_service" {
  name            = "${local.name}-product-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.product_service.arn
  desired_count   = var.product_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.product_service.arn
    container_name   = "product-service"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]
}

############################
# Order Service
############################

resource "aws_ecs_task_definition" "order_service" {
  family                   = "${local.name}-order-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.service_cpu
  memory                   = var.service_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "order-service"
      image     = "${aws_ecr_repository.order_service.repository_url}:${var.order_service_image_tag}"
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      environment = [
        { name = "DB_HOST", value = aws_rds_cluster.aurora.endpoint },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USER", value = var.db_master_username },
        { name = "ORDERS_QUEUE_URL", value = aws_sqs_queue.orders.url },
        { name = "COGNITO_USER_POOL_ID", value = aws_cognito_user_pool.main.id },
        { name = "COGNITO_CLIENT_ID", value = aws_cognito_user_pool_client.app.id },
      ]
      secrets = [
        { name = "DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db_master.arn}:password::" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.order_service.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "order-service"
        }
      }
    }
  ])

  tags = { Name = "${local.name}-order-service-task" }
}

resource "aws_ecs_service" "order_service" {
  name            = "${local.name}-order-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.order_service.arn
  desired_count   = var.order_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.order_service.arn
    container_name   = "order-service"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]
}
