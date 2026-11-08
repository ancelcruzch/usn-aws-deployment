variable "name" {
  description = "Prefijo de nombres (identificador RDS, security group, secreto)."
  type        = string
}

variable "environment" {
  description = "Ambiente; forma parte del nombre del secreto."
  type        = string
}

variable "vpc_id" {
  description = "VPC de la base de datos."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets privadas para el DB subnet group (al menos dos AZs)."
  type        = list(string)
}

variable "allowed_security_group_id" {
  description = "Security group autorizado a conectarse al puerto 3306 (workers/pods de EKS)."
  type        = string
}

variable "engine_version" {
  description = "Versión de MySQL."
  type        = string
}

variable "instance_class" {
  description = "Clase de instancia RDS."
  type        = string
}

variable "allocated_storage" {
  description = "Almacenamiento inicial en GiB."
  type        = number
}

variable "max_allocated_storage" {
  description = "Límite de autoescalado del almacenamiento en GiB (0 lo desactiva)."
  type        = number
}

variable "db_name" {
  description = "Base de datos inicial."
  type        = string
}

variable "username" {
  description = "Usuario administrador."
  type        = string
}

variable "multi_az" {
  description = "Standby en otra AZ."
  type        = bool
}

variable "backup_retention_days" {
  description = "Días de retención de backups automáticos."
  type        = number
}

variable "skip_final_snapshot" {
  description = "No crear snapshot final al destruir."
  type        = bool
}

variable "log_retention_days" {
  description = "Retención de los logs de RDS en CloudWatch."
  type        = number
}
