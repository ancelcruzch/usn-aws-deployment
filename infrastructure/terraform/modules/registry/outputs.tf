output "repository_urls" {
  description = "URL de cada repositorio."
  value       = { for name, repo in aws_ecr_repository.app : name => repo.repository_url }
}

output "repository_arns" {
  description = "ARN de cada repositorio (para la política del rol de CD)."
  value       = [for repo in aws_ecr_repository.app : repo.arn]
}
