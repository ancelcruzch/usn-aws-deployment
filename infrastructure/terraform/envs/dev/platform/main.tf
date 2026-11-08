# Capa PLATFORM del ambiente dev: todo lo que genera costo por hora.
# Se crea al empezar a trabajar y se destruye al terminar (terraform destroy).
#
#   network ──► cluster ──► database
#                  │            │
#                  └────────────┴──► observability (dashboard, alarmas)
#
# Depende de la capa base (ECR, identidad de GitHub Actions), que debe existir.

# Identidad del pipeline de CD creada por la capa base.
data "terraform_remote_state" "base" {
  backend = "s3"

  config = {
    bucket = "usn-tfstate-${var.aws_account_id}"
    key    = "eks/${var.environment}/base.tfstate"
    region = var.aws_region
  }
}

module "network" {
  source = "../../../modules/network"

  environment          = var.environment
  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
}

module "cluster" {
  source = "../../../modules/cluster"

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

  app_namespace    = var.app_namespace
  app_deployer_arn = data.terraform_remote_state.base.outputs.github_cd_principal_arn

  log_retention_days = var.log_retention_days
}

module "database" {
  source = "../../../modules/database"

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

module "observability" {
  source = "../../../modules/observability"

  aws_region            = var.aws_region
  cluster_name          = module.cluster.cluster_name
  app_namespace         = var.app_namespace
  application_log_group = module.cluster.application_log_group
  db_identifier         = module.database.identifier
  alert_emails          = var.alert_emails
}

# Namespace de la aplicación: lo crea Terraform para que el pipeline de CD
# (con permisos solo dentro de él) pueda desplegar sin pasos manuales.
# Al destruir se elimina primero: Kubernetes borra sus Services y con ellos
# los balanceadores de carga, antes de que se borre la VPC.
resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.app_namespace

    labels = {
      "app.kubernetes.io/part-of" = "usn"
    }
  }

  depends_on = [module.cluster]
}
