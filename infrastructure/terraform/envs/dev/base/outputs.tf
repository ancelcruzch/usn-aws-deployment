output "ecr_registry" {
  description = "Host del registro ECR (variable ECR_REGISTRY del repositorio)."
  value       = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_repository_urls" {
  description = "URL de cada repositorio ECR."
  value       = module.registry.repository_urls
}

output "github_cd_principal_arn" {
  description = "Identidad IAM del pipeline; la capa platform le da acceso al cluster."
  value       = module.cicd.principal_arn
}

output "github_cd_user_name" {
  description = "Usuario IAM del pipeline; crear su access key con: aws iam create-access-key --user-name <este valor>."
  value       = module.cicd.user_name
}

output "github_cd_role_arn" {
  description = "Rol OIDC (solo con github_auth_mode = oidc)."
  value       = module.cicd.role_arn
}

output "budget_name" {
  description = "Presupuesto mensual en AWS Budgets."
  value       = module.budget.budget_name
}
