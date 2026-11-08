# Base de datos gestionada: Amazon RDS for MySQL en las subnets privadas.
# El backend en EKS es el único cliente permitido; la base no tiene IP pública.

locals {
  db_identifier = "${var.name}-mysql"
}

resource "aws_db_subnet_group" "mysql" {
  name        = local.db_identifier
  description = "Subnets privadas para RDS MySQL de USN"
  subnet_ids  = var.subnet_ids
}

resource "aws_security_group" "mysql" {
  name        = "${local.db_identifier}-sg"
  description = "MySQL accesible solo desde los workers y pods de EKS"
  vpc_id      = var.vpc_id
}

# Con VPC CNI los pods usan el security group de los nodos, que en este node
# group (sin launch template propio) es el security group primario del cluster:
# el módulo raíz lo pasa como allowed_security_group_id.
resource "aws_vpc_security_group_ingress_rule" "mysql_from_eks" {
  security_group_id            = aws_security_group.mysql.id
  description                  = "MySQL desde EKS"
  referenced_security_group_id = var.allowed_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}

# Contraseña generada por Terraform: nunca se escribe en el repositorio. Queda en
# el estado remoto (bucket S3 cifrado y privado) y en Secrets Manager.
resource "random_password" "db" {
  length  = 32
  special = false
}

# Los log groups se crean antes que la instancia para fijar su retención.
resource "aws_cloudwatch_log_group" "rds" {
  for_each = toset(["error", "slowquery"])

  name              = "/aws/rds/instance/${local.db_identifier}/${each.key}"
  retention_in_days = var.log_retention_days
}

resource "aws_db_instance" "mysql" {
  identifier = local.db_identifier

  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.username
  password = random_password.db.result
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.mysql.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period    = var.backup_retention_days
  auto_minor_version_upgrade = true
  apply_immediately          = true

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  # Entorno académico: se debe poder destruir y recrear con Terraform.
  deletion_protection       = false
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.db_identifier}-final"

  depends_on = [aws_cloudwatch_log_group.rds]
}

# Credenciales de conexión para la aplicación. El pipeline de CD las lee con su
# rol OIDC y crea el Secret de Kubernetes; nadie las copia a mano.
resource "aws_secretsmanager_secret" "db" {
  name        = "${var.name}/${var.environment}/mysql"
  description = "Credenciales del backend USN para RDS MySQL"

  # Permite destruir y volver a crear el entorno con el mismo nombre.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.username
    password = random_password.db.result
    host     = aws_db_instance.mysql.address
    port     = aws_db_instance.mysql.port
    dbname   = var.db_name
    jdbc_url = "jdbc:mysql://${aws_db_instance.mysql.address}:${aws_db_instance.mysql.port}/${var.db_name}"
  })
}
