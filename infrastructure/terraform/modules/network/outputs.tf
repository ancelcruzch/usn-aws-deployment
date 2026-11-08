output "vpc_id" {
  description = "ID de la VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas."
  value       = module.vpc.public_subnets
}
