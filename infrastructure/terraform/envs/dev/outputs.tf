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

output "configure_kubectl" {
  description = "Comando a ejecutar después del despliegue para configurar kubectl."
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

output "db_secret_arn" {
  description = "Secreto de Secrets Manager con usuario, contraseña y endpoint de la base."
  value       = module.database.secret_arn
}

output "db_secret_name" {
  description = "Nombre del secreto (variable DB_SECRET_ID del repositorio)."
  value       = module.database.secret_name
}

################################################################################
# Registro de imágenes y CI/CD
################################################################################

output "ecr_registry" {
  description = "Host del registro ECR (para docker login y nombres de imagen)."
  value       = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_repository_urls" {
  description = "URL de cada repositorio ECR."
  value       = module.registry.repository_urls
}

output "github_cd_principal_arn" {
  description = "Identidad IAM que usa GitHub Actions (usuario o rol)."
  value       = module.cicd.principal_arn
}

output "github_cd_user_name" {
  description = "Usuario IAM del pipeline; crear su access key con: aws iam create-access-key --user-name <este valor>."
  value       = module.cicd.user_name
}

output "github_cd_role_arn" {
  description = "Rol OIDC (solo con github_auth_mode = oidc; variable AWS_ROLE_ARN del repositorio)."
  value       = module.cicd.role_arn
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
