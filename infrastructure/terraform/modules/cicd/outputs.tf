output "principal_arn" {
  description = "ARN de la identidad del pipeline (usuario o rol)."
  value       = local.principal_arn
}

output "role_arn" {
  description = "ARN del rol OIDC (null en modo iam_user)."
  value       = one(aws_iam_role.github_cd[*].arn)
}

output "user_name" {
  description = "Usuario IAM del pipeline (null en modo oidc)."
  value       = one(aws_iam_user.github_cd[*].name)
}
