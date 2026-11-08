# Ambiente dev: compone los módulos de la plataforma.
#
#   network ──► cluster ──► database
#      │           │            │
#      │           ├────────────┼──► cicd  (GitHub Actions: ECR + EKS + secreto BD)
#      │           │            │
#      │           └────────────┴──► observability (dashboard, alarmas, budget)
#   registry ──────────────────────► cicd

module "network" {
  source = "../../modules/network"

  environment          = var.environment
  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
}

module "cluster" {
  source = "../../modules/cluster"

  cluster_name                 = var.cluster_name
  environment                  = var.environment
  kubernetes_version           = var.kubernetes_version
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_disk_size      = var.node_disk_size

  log_retention_days = var.log_retention_days
}

module "database" {
  source = "../../modules/database"

  name        = var.cluster_name
  environment = var.environment

  vpc_id                    = module.network.vpc_id
  subnet_ids                = module.network.private_subnet_ids
  allowed_security_group_id = module.cluster.cluster_primary_security_group_id

  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  db_name               = var.db_name
  username              = var.db_username
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  skip_final_snapshot   = var.db_skip_final_snapshot

  log_retention_days = var.log_retention_days
}

module "registry" {
  source = "../../modules/registry"

  repositories     = var.ecr_repositories
  keep_last_images = var.ecr_keep_last_images
}

module "cicd" {
  source = "../../modules/cicd"

  name                 = var.cluster_name
  auth_mode            = var.github_auth_mode
  github_repository    = var.github_repository
  deploy_branch        = var.github_deploy_branch
  create_oidc_provider = var.create_github_oidc_provider

  ecr_repository_arns = module.registry.repository_arns
  cluster_name        = module.cluster.cluster_name
  cluster_arn         = module.cluster.cluster_arn
  app_namespace       = var.app_namespace
  db_secret_arn       = module.database.secret_arn
}

module "observability" {
  source = "../../modules/observability"

  aws_region            = var.aws_region
  cluster_name          = module.cluster.cluster_name
  app_namespace         = var.app_namespace
  application_log_group = module.cluster.application_log_group
  db_identifier         = module.database.identifier

  alert_emails       = var.alert_emails
  monthly_budget_usd = var.monthly_budget_usd
}
