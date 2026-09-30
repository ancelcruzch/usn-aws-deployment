module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.26.0"

  name = var.cluster_name
  # 1.35 está en soporte estándar y a una versión menor de kubectl 1.34.1.
  kubernetes_version = "1.35"

  endpoint_public_access  = true
  endpoint_private_access = true
  # Acceso desde la Mac, sujeto a autenticación IAM y autorización EKS.
  # Se puede restringir posteriormente a la IP pública de administración (/32).
  endpoint_public_access_cidrs = ["0.0.0.0/0"]

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Evita cargos de soporte extendido: AWS actualizará el control plane al
  # terminar el soporte estándar. Revisar antes kubectl, workers y add-ons.
  upgrade_policy = {
    support_type = "STANDARD"
  }

  cloudwatch_log_group_retention_in_days = 7

  # Componentes de red/DNS del cluster, no despliegues de la aplicación.
  addons = {
    vpc-cni = {
      before_compute = true
    }
    kube-proxy = {
      before_compute = true
    }
    coredns = {}
  }

  eks_managed_node_groups = {
    usn-workers = {
      name = "usn-workers"
      # El módulo reemplaza creando primero: el sufijo evita colisiones de nombre.
      use_name_prefix = true

      subnet_ids     = module.vpc.private_subnets
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"

      desired_size = 1
      min_size     = 1
      max_size     = 2
      disk_size    = 20

      # disk_size se envía a EKS solo sin launch template personalizado.
      create_launch_template     = false
      use_custom_launch_template = false

      # Sin template personalizado, EKS asigna su security group del cluster.

      update_config = {
        max_unavailable = 1
      }
    }
  }

  tags = {
    Project     = "usn"
    Environment = var.environment
  }
}
