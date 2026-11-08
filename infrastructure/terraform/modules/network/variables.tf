variable "environment" {
  description = "Ambiente; forma parte del nombre de la VPC."
  type        = string
}

variable "cluster_name" {
  description = "Cluster EKS que usará las subnets (para las etiquetas de descubrimiento de balanceadores)."
  type        = string
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC."
  type        = string
}

variable "private_subnet_cidrs" {
  description = "CIDRs de las subnets privadas, una por AZ."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs de las subnets públicas, una por AZ."
  type        = list(string)
}
