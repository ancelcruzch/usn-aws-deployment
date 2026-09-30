output "cluster_name" {
  description = "Nombre del cluster EKS."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint HTTPS de la API Kubernetes."
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "ID de la VPC del proyecto."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs de las dos subnets públicas."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs de las dos subnets privadas usadas por los workers."
  value       = module.vpc.private_subnets
}

output "managed_node_group_name" {
  description = "Nombre del EKS Managed Node Group."
  value       = split(":", module.eks.eks_managed_node_groups["usn-workers"].node_group_id)[1]
}

output "configure_kubectl" {
  description = "Comando a ejecutar después del despliegue para configurar kubectl."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
