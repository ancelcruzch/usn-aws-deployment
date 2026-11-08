variable "cluster_name" {
  description = "Nombre del cluster EKS."
  type        = string
}

variable "environment" {
  description = "Ambiente, usado en etiquetas."
  type        = string
}

variable "kubernetes_version" {
  description = "Versión de Kubernetes del control plane."
  type        = string
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs que pueden llegar al endpoint público de la API."
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC donde se crea el cluster."
  type        = string
}

variable "subnet_ids" {
  description = "Subnets privadas para el control plane y los workers."
  type        = list(string)
}

variable "node_instance_types" {
  description = "Tipos de instancia EC2 de los workers."
  type        = list(string)
}

variable "node_desired_size" {
  description = "Número inicial de workers."
  type        = number
}

variable "node_min_size" {
  description = "Número mínimo de workers."
  type        = number
}

variable "node_max_size" {
  description = "Número máximo de workers."
  type        = number
}

variable "node_disk_size" {
  description = "Disco raíz de cada worker en GiB."
  type        = number
}

variable "log_retention_days" {
  description = "Retención de los logs del control plane y de Container Insights."
  type        = number
}
