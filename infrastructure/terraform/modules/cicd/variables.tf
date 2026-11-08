variable "name" {
  description = "Prefijo del nombre del rol."
  type        = string
}

variable "auth_mode" {
  description = "Cómo se autentica GitHub Actions: iam_user (access key en GitHub Secrets) u oidc (rol federado, sin claves)."
  type        = string

  validation {
    condition     = contains(["iam_user", "oidc"], var.auth_mode)
    error_message = "auth_mode debe ser iam_user u oidc."
  }
}

variable "github_repository" {
  description = "Repositorio autorizado, en formato owner/repo (modo oidc)."
  type        = string
}

variable "deploy_branch" {
  description = "Única rama que puede asumir el rol (modo oidc)."
  type        = string
}

variable "create_oidc_provider" {
  description = "Crear el proveedor OIDC de GitHub (modo oidc; false si ya existe en la cuenta)."
  type        = bool
}

variable "ecr_repository_arns" {
  description = "Repositorios en los que el rol puede publicar imágenes."
  type        = list(string)
}

variable "cluster_name" {
  description = "Cluster EKS donde se despliega."
  type        = string
}

variable "cluster_arn" {
  description = "ARN del cluster (para eks:DescribeCluster)."
  type        = string
}

variable "app_namespace" {
  description = "Namespace Kubernetes que el rol puede administrar."
  type        = string
}

variable "db_secret_arn" {
  description = "Secreto de la base de datos que el pipeline puede leer."
  type        = string
}
