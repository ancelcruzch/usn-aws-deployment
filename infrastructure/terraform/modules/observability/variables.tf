variable "aws_region" {
  description = "Región de las métricas del dashboard."
  type        = string
}

variable "cluster_name" {
  description = "Cluster EKS monitoreado (dimensión ClusterName de Container Insights)."
  type        = string
}

variable "app_namespace" {
  description = "Namespace de la aplicación."
  type        = string
}

variable "application_log_group" {
  description = "Log group con los logs de los contenedores."
  type        = string
}

variable "db_identifier" {
  description = "Identificador de la instancia RDS."
  type        = string
}

variable "alert_emails" {
  description = "Correos para alarmas (vacío desactiva notificaciones)."
  type        = list(string)
}
