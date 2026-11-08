# Capa BASE del ambiente dev: recursos permanentes y de costo casi nulo.
# Se crea una vez y no se destruye entre sesiones de trabajo:
#
#   registry ──► cicd      imágenes en ECR e identidad de GitHub Actions
#   budget                 presupuesto mensual con alertas
#
# Así, al destruir la capa platform (lo que cuesta), no se pierden las imágenes
# ni cambian las credenciales guardadas en GitHub.

module "registry" {
  source = "../../../modules/registry"

  repositories     = var.ecr_repositories
  keep_last_images = var.ecr_keep_last_images
}

module "cicd" {
  source = "../../../modules/cicd"

  name                 = var.cluster_name
  auth_mode            = var.github_auth_mode
  github_repository    = var.github_repository
  deploy_branch        = var.github_deploy_branch
  create_oidc_provider = var.create_github_oidc_provider

  ecr_repository_arns = module.registry.repository_arns
  aws_region          = var.aws_region
  cluster_name        = var.cluster_name
  db_secret_name      = "${var.cluster_name}/${var.environment}/mysql"
}

module "budget" {
  source = "../../../modules/budget"

  name               = var.cluster_name
  monthly_budget_usd = var.monthly_budget_usd
  alert_emails       = var.alert_emails
}
