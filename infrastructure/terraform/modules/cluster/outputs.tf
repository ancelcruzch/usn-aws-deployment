output "cluster_name" {
  description = "Nombre del cluster EKS."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "ARN del cluster EKS."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint HTTPS de la API Kubernetes."
  value       = module.eks.cluster_endpoint
}

output "cluster_primary_security_group_id" {
  description = "Security group de los workers y pods (VPC CNI); se usa para permitir acceso a RDS."
  value       = module.eks.cluster_primary_security_group_id
}

output "node_group_name" {
  description = "Nombre real del Managed Node Group (incluye sufijo)."
  value       = split(":", module.eks.eks_managed_node_groups["usn-workers"].node_group_id)[1]
}

output "application_log_group" {
  description = "Log group con los logs de los contenedores (Fluent Bit)."
  value       = aws_cloudwatch_log_group.container_insights["application"].name
}

output "cluster_certificate_authority_data" {
  description = "Certificado de la CA del cluster (base64), para configurar el provider kubernetes."
  value       = module.eks.cluster_certificate_authority_data
}
