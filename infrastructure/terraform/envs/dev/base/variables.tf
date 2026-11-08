variable "aws_region" {
  description = "Región AWS (la organización de la cuenta solo permite us-east-2)."
  type        = string
  default     = "us-east-2"
}

variable "aws_account_id" {
  description = "Única cuenta AWS en la que Terraform puede operar."
  type        = string
  default     = "055147668929"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "El ID de cuenta debe tener 12 dígitos."
  }
}

variable "environment" {
  description = "Ambiente usado en nombres y etiquetas."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,19}$", var.environment))
    error_message = "El ambiente debe comenzar con una letra minúscula y tener hasta 20 caracteres alfanuméricos o guiones."
  }
}

variable "cluster_name" {
  description = "Nombre del cluster EKS (lo crea la capa platform); prefijo de los nombres."
  type        = string
  default     = "usn-cluster"
}

variable "ecr_repositories" {
  description = "Repositorios ECR a crear (uno por imagen de la aplicación)."
  type        = set(string)
  default     = ["usn-backend", "usn-frontend", "usn-socket", "usn-ai-service"]
}

variable "ecr_keep_last_images" {
  description = "Cantidad de imágenes que conserva cada repositorio ECR."
  type        = number
  default     = 15
}

variable "github_auth_mode" {
  description = "Autenticación de GitHub Actions en AWS: iam_user (access key en GitHub Secrets) u oidc (sin claves). Esta cuenta bloquea OIDC."
  type        = string
  default     = "iam_user"
}

variable "github_repository" {
  description = "Repositorio GitHub autorizado (modo oidc), formato owner/repo."
  type        = string
  default     = "ancelcruzch/usn-aws-deployment"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Usar el formato owner/repo."
  }
}

variable "github_deploy_branch" {
  description = "Rama que puede asumir el rol (modo oidc)."
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Crear el proveedor OIDC de GitHub (modo oidc; false si ya existe)."
  type        = bool
  default     = true
}

variable "alert_emails" {
  description = "Correos que reciben las alertas de presupuesto."
  type        = list(string)
  default     = []
}

variable "monthly_budget_usd" {
  description = "Presupuesto mensual en USD (alertas al 50, 80 y 100 %)."
  type        = number
  default     = 100
}
