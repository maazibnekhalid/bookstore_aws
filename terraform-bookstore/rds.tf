resource "random_password" "db_master" {
  length  = 20
  special = false # avoid characters Aurora master password disallows
}

resource "aws_secretsmanager_secret" "db_master" {
  name = "${local.name}-aurora-master-credentials"
}

resource "aws_secretsmanager_secret_version" "db_master" {
  secret_id = aws_secretsmanager_secret.db_master.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.db_master.result
  })
}

resource "aws_rds_cluster_parameter_group" "aurora" {
  name        = "${local.name}-aurora-params"
  family      = "aurora-mysql8.0"
  description = "Aurora MySQL cluster parameter group for ${local.name}"
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier              = "${local.name}-aurora"
  engine                          = "aurora-mysql"
  engine_mode                     = "provisioned"
  engine_version                  = "8.0.mysql_aurora.3.10.3"
  database_name                   = var.db_name
  master_username                 = var.db_master_username
  master_password                 = random_password.db_master.result
  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  backup_retention_period      = var.db_backup_retention_days
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "mon:04:30-mon:05:30"

  storage_encrypted         = true
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name}-aurora-final-snapshot"

  tags = { Name = "${local.name}-aurora" }
}

# Writer instance (index 0) + reader instances (index 1..N)
resource "aws_rds_cluster_instance" "aurora_instances" {
  count              = 1 + var.db_reader_count
  identifier         = count.index == 0 ? "${local.name}-aurora-writer" : "${local.name}-aurora-reader-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  # Lower promotion tier for the writer so it's preferred during failover;
  # instance 0 is the writer purely by virtue of being created first and
  # having the lowest failover priority.
  promotion_tier = count.index == 0 ? 0 : count.index

  tags = {
    Name = count.index == 0 ? "${local.name}-aurora-writer" : "${local.name}-aurora-reader-${count.index}"
    Role = count.index == 0 ? "writer" : "reader"
  }
}
