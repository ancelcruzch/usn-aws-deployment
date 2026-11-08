################################################################################
# Red y cluster
################################################################################

output "vpc_id" {
  description = "ID de la VPC del proyecto."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas (workers y RDS)."
  value       = module.network.private_subnet_ids
}

output "cluster_name" {
  description = "Nombre del cluster EKS."
  value       = module.cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint HTTPS de la API Kubernetes."
  value       = module.cluster.cluster_endpoint
}

output "managed_node_group_name" {
  description = "Nombre del EKS Managed Node Group."
  value       = module.cluster.node_group_name
}

output "app_namespace" {
  description = "Namespace de la aplicación (creado por Terraform)."
  value       = kubernetes_namespace_v1.app.metadata[0].name
}

output "configure_kubectl" {
  description = "Comando para configurar kubectl."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.cluster.cluster_name}"
}

################################################################################
# Base de datos
################################################################################

output "db_endpoint" {
  description = "Host de RDS MySQL (solo accesible desde EKS)."
  value       = module.database.address
}

output "db_jdbc_url" {
  description = "URL JDBC para SPRING_DATASOURCE_URL."
  value       = module.database.jdbc_url
}

output "db_secret_name" {
  description = "Secreto con usuario, contraseña y endpoint (variable DB_SECRET_ID del repositorio)."
  value       = module.database.secret_name
}

################################################################################
# Monitoreo
################################################################################

output "cloudwatch_dashboard_url" {
  description = "Dashboard de CloudWatch con métricas de nodos, pods, RDS y errores."
  value       = module.observability.dashboard_url
}

output "application_log_group" {
  description = "Log group con los logs de los contenedores (Fluent Bit)."
  value       = module.cluster.application_log_group
}
