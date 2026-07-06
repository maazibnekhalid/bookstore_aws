############################
# SQS - Orders Queue + Dead Letter Queue
############################

resource "aws_sqs_queue" "orders_dlq" {
  name                      = "${local.name}-orders-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = { Name = "${local.name}-orders-dlq" }
}

resource "aws_sqs_queue" "orders" {
  name                       = "${local.name}-orders-queue"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = 345600 # 4 days

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 5
  })

  tags = { Name = "${local.name}-orders-queue" }
}

############################
# Lambda: Order Processing (SQS-triggered)
############################

data "archive_file" "order_processing" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/order_processing"
  output_path = "${path.module}/lambda/order_processing.zip"
}

resource "aws_cloudwatch_log_group" "order_processing_lambda" {
  name              = "/aws/lambda/${local.name}-order-processing"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "order_processing" {
  function_name    = "${local.name}-order-processing"
  role             = aws_iam_role.lambda_order_processing.arn
  handler          = "handler.handler"
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  filename         = data.archive_file.order_processing.output_path
  source_code_hash = data.archive_file.order_processing.output_base64sha256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_HOST       = aws_rds_cluster.aurora.endpoint
      DB_NAME       = var.db_name
      DB_USER       = var.db_master_username
      DB_SECRET_ARN = aws_secretsmanager_secret.db_master.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.order_processing_lambda]

  tags = { Name = "${local.name}-order-processing" }
}

resource "aws_lambda_event_source_mapping" "orders_queue_to_lambda" {
  event_source_arn = aws_sqs_queue.orders.arn
  function_name    = aws_lambda_function.order_processing.arn
  batch_size       = 10
}
