################################################################################
# Cuenta y región
################################################################################

variable "aws_region" {
  description = "Región AWS donde se crea la infraestructura."
  type        = string
  default     = "us-east-2"
}

variable "aws_account_id" {
  description = "Única cuenta AWS en la que Terraform puede operar (protección contra despliegues en la cuenta equivocada)."
  type        = string
  default     = "055147668929"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "El ID de cuenta debe tener 12 dígitos."
  }
}

variable "environment" {
  description = "Ambiente usado en nombres y etiquetas de los recursos."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,19}$", var.environment))
    error_message = "El ambiente debe comenzar con una letra minúscula y tener hasta 20 caracteres alfanuméricos o guiones."
  }
}

################################################################################
# Red
################################################################################

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDRs de las subnets privadas (una por AZ) donde corren los workers."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs de las subnets públicas (una por AZ) para NAT y balanceadores."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

################################################################################
# EKS
################################################################################

variable "cluster_name" {
  description = "Nombre del cluster EKS."
  type        = string
  default     = "usn-cluster"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$", var.cluster_name))
    error_message = "El nombre debe tener entre 1 y 100 caracteres y usar letras, números, guiones o guiones bajos."
  }
}

variable "kubernetes_version" {
  description = "Versión de Kubernetes del control plane."
  type        = string
  default     = "1.35"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs que pueden llegar al endpoint público de la API de EKS. GitHub Actions (runners hospedados) necesita acceso público; restringir a /32 de administración si el CD usa runners propios."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "Tipos de instancia EC2 del Managed Node Group."
  type        = list(string)
  default     = ["c7i-flex.large"]
}

variable "node_desired_size" {
  description = "Número inicial de workers."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Número mínimo de workers."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Número máximo de workers."
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Tamaño en GiB del disco raíz de cada worker."
  type        = number
  default     = 20
}

variable "app_namespace" {
  description = "Namespace Kubernetes de la aplicación; el rol de CD solo tiene permisos dentro de él."
  type        = string
  default     = "usn"
}

################################################################################
# Container registry
################################################################################

variable "ecr_repositories" {
  description = "Repositorios ECR a crear (uno por imagen de la aplicación)."
  type        = set(string)
  default     = ["usn-backend", "usn-frontend", "usn-socket", "usn-ai-service"]
}

variable "ecr_keep_last_images" {
  description = "Cantidad de imágenes que conserva cada repositorio ECR; las más antiguas se eliminan."
  type        = number
  default     = 15
}

################################################################################
# Base de datos (Amazon RDS for MySQL)
################################################################################

variable "db_engine_version" {
  description = "Versión de MySQL en RDS (versión mayor; AWS aplica la menor por defecto)."
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "Clase de instancia RDS."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Almacenamiento inicial en GiB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Límite de autoescalado del almacenamiento en GiB (0 lo desactiva)."
  type        = number
  default     = 50
}

variable "db_name" {
  description = "Base de datos que crea RDS y que usa el backend."
  type        = string
  default     = "railway"
}

variable "db_username" {
  description = "Usuario administrador de la base de datos (la contraseña la genera Terraform)."
  type        = string
  default     = "usn"
}

variable "db_multi_az" {
  description = "Réplica en standby en otra AZ (duplica el costo)."
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Días de retención de backups automáticos (0 los desactiva)."
  type        = number
  default     = 1
}

variable "db_skip_final_snapshot" {
  description = "No crear snapshot al destruir la base. false conserva los datos en un snapshot (que tiene costo)."
  type        = bool
  default     = true
}

################################################################################
# CI/CD (GitHub Actions)
################################################################################

variable "github_auth_mode" {
  description = "Autenticación de GitHub Actions en AWS: iam_user (access key en GitHub Secrets) u oidc (sin claves). Esta cuenta bloquea OIDC, por eso el valor por defecto es iam_user."
  type        = string
  default     = "iam_user"
}

variable "github_repository" {
  description = "Repositorio GitHub autorizado a asumir el rol de CD, en formato owner/repo."
  type        = string
  default     = "ancelcruzch/usn-aws-deployment"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Usar el formato owner/repo."
  }
}

variable "github_deploy_branch" {
  description = "Rama desde la cual GitHub Actions puede publicar imágenes y desplegar."
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Crear el proveedor OIDC de GitHub. Poner false si ya existe en la cuenta (solo puede haber uno por URL)."
  type        = bool
  default     = true
}

################################################################################
# Monitoreo y costos
################################################################################

variable "log_retention_days" {
  description = "Días de retención de los logs de CloudWatch (control plane y Container Insights)."
  type        = number
  default     = 7
}

variable "alert_emails" {
  description = "Correos que reciben alarmas de CloudWatch y alertas de presupuesto. Vacío desactiva las notificaciones."
  type        = list(string)
  default     = []
}

variable "monthly_budget_usd" {
  description = "Presupuesto mensual en USD; se alerta al 50 %, 80 % y 100 % (real) y al 100 % (pronóstico)."
  type        = number
  default     = 50
}
