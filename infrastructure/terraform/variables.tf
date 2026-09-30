variable "aws_region" {
  description = "Región AWS donde se crea la infraestructura."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nombre del cluster EKS."
  type        = string
  default     = "usn-cluster"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$", var.cluster_name))
    error_message = "El nombre debe tener entre 1 y 100 caracteres y usar letras, números, guiones o guiones bajos."
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
